import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import { zeroAddress } from '../constants.hardhat';
import type {
	ERC721ExchangeUpgradeable,
	ERC721ExchangeUpgradeableUpgraded,
	OrderBookUpgradeable,
	RoyaltyEngineV1,
	RoyaltyRegistry,
	TestERC721,
	WETHMock
} from '../typechain';

chai.use(solidity);

const SYSTEM_FEE = 29; // 2,9%

describe('ERC721Exchange', () => {
	let contractWETH: WETHMock;
	let contractRoyaltyRegistry: RoyaltyRegistry;
	let contractRoyaltyEngineV1: RoyaltyEngineV1;
	let contractOrderBookUpgradeable: OrderBookUpgradeable;
	let contract: ERC721ExchangeUpgradeable;
	let contractERC721: TestERC721;

	beforeEach(async () => {
		const WETHContract = await ethers.getContractFactory('WETHMock');
		contractWETH = (await WETHContract.deploy()) as WETHMock;

		const RoyaltyRegistryContract = await ethers.getContractFactory('RoyaltyRegistry');
		contractRoyaltyRegistry = (await upgrades.deployProxy(RoyaltyRegistryContract, [], {
			initializer: '__RoyaltyRegistry_init',
			kind: 'transparent'
		})) as RoyaltyRegistry;
		await contractRoyaltyRegistry.deployed();

		const RoyaltyEngineV1Contract = await ethers.getContractFactory('RoyaltyEngineV1');
		contractRoyaltyEngineV1 = (await upgrades.deployProxy(RoyaltyEngineV1Contract, [contractRoyaltyRegistry.address], {
			initializer: '__RoyaltyEngineV1_init',
			kind: 'transparent'
		})) as RoyaltyEngineV1;
		await contractRoyaltyEngineV1.deployed();

		const OrderBookUpgradeableContract = await ethers.getContractFactory('OrderBookUpgradeable');
		contractOrderBookUpgradeable = (await upgrades.deployProxy(OrderBookUpgradeableContract, [], {
			initializer: '__OrderBook_init',
			kind: 'transparent'
		})) as OrderBookUpgradeable;
		await contractOrderBookUpgradeable.deployed();

		const ERC721ExchangeUpgradeableContract = await ethers.getContractFactory('ERC721ExchangeUpgradeable');
		contract = (await upgrades.deployProxy(
			ERC721ExchangeUpgradeableContract,
			[SYSTEM_FEE, contractRoyaltyEngineV1.address, contractOrderBookUpgradeable.address, contractWETH.address],
			{
				initializer: '__ERC721Exchange_init',
				kind: 'transparent'
			}
		)) as ERC721ExchangeUpgradeable;
		await contract.deployed();

		await contractOrderBookUpgradeable.addOrderKeeper(contract.address);

		const TestERC721Contract = await ethers.getContractFactory('TestERC721');
		contractERC721 = (await TestERC721Contract.deploy()) as TestERC721;
		await contractERC721.deployed();
	});

	describe('base v1', () => {
		describe('initialization', () => {
			it('version should equal "1"', async () => {
				const version = await contract.version();

				expect(version.toString()).to.equal('1');
			});

			it('should set sender as owner', async () => {
				const [{ address }] = await ethers.getSigners();
				const owner = await contract.owner();

				expect(owner).to.equal(address);
			});
		});

		describe('ownable', () => {
			it('should swap ownership', async () => {
				const [, { address: addressAlternative }] = await ethers.getSigners();

				await contract.transferOwnership(addressAlternative);
				const owner = await contract.owner();

				expect(owner).to.equal(addressAlternative);
			});

			it('should fail to swap ownership', async () => {
				const [, accountAlternative] = await ethers.getSigners();

				await expect(contract.connect(accountAlternative).transferOwnership(accountAlternative.address)).to.be.revertedWith(
					'Ownable: caller is not the owner'
				);
			});
		});

		describe('orders', () => {
			describe('sell', () => {
				it('should create new sell order and cancel order', async () => {
					const [account] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					const expiration = BigNumber.from(timestamp);
					const price = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contractERC721.mintNext(account.address);
					await expect(contractERC721.setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(account.address, contract.address, true);

					await expect(contract.bookSellOrder(contractERC721.address, 1, expiration, price, zeroAddress))
						.to.emit(contract, 'SellOrderBooked')
						.withArgs(account.address, contractERC721.address, 1, expiration, price, zeroAddress);

					const order = await contract.getSellOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(expiration);
					expect(order[1]).to.be.equal(price);

					await expect(contract.cancelSellOrder(contractERC721.address, 1))
						.to.emit(contract, 'SellOrderCanceled')
						.withArgs(account.address, contractERC721.address, 1);

					const canceledOrder = await contract.getSellOrder(account.address, contractERC721.address, 1);
					expect(canceledOrder[0]).to.be.equal(zeroAddress);
				});

				it('should create new sell order and execute order', async () => {
					const [account, buyer, maker] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					// const startingBuyerBalance = await buyer.getBalance();

					const expiration = BigNumber.from(timestamp);
					const price = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contract.setSystemFeeWallet(maker.address);

					await contractERC721.mintNext(account.address);
					await expect(contractERC721.setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(account.address, contract.address, true);

					await expect(contract.bookSellOrder(contractERC721.address, 1, expiration, price, zeroAddress))
						.to.emit(contract, 'SellOrderBooked')
						.withArgs(account.address, contractERC721.address, 1, expiration, price, zeroAddress);

					const order = await contract.getSellOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(expiration);
					expect(order[1]).to.be.equal(price);
					expect(order[2]).to.be.equal(zeroAddress);

					const startingAccountBalance = await account.getBalance();

					await expect(
						contract
							.connect(buyer)
							.exerciseSellOrder(account.address, contractERC721.address, 1, expiration, price, buyer.address, zeroAddress, {
								value: price
							})
					)
						.to.emit(contract, 'SellOrderExercised')
						.withArgs(account.address, buyer.address, buyer.address, contractERC721.address, 1, price, zeroAddress)
						.and.to.emit(contract, 'SellOrderCanceled')
						.withArgs(account.address, contractERC721.address, 1);

					expect((await account.getBalance()).toString()).to.be.equal(
						BigNumber.from(startingAccountBalance)
							.add(BigNumber.from(price).sub(BigNumber.from(price).mul(SYSTEM_FEE).div(1000)))
							.toString()
					);

					const canceledOrder = await contract.getSellOrder(account.address, contractERC721.address, 1);
					expect(canceledOrder[0]).to.be.equal(zeroAddress);
				});

				it('should create new sell order and execute order using WETH', async () => {
					const [account, buyer, maker] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					const expiration = BigNumber.from(timestamp);
					const price = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contract.setSystemFeeWallet(maker.address);

					await expect(contractWETH.connect(buyer).deposit({ value: price }))
						.to.emit(contractWETH, 'Deposit')
						.withArgs(buyer.address, price);
					await expect(contractWETH.connect(buyer).approve(contract.address, price))
						.to.emit(contractWETH, 'Approval')
						.withArgs(buyer.address, contract.address, price);

					await contractERC721.mintNext(account.address);
					await expect(contractERC721.setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(account.address, contract.address, true);

					await expect(contract.bookSellOrder(contractERC721.address, 1, expiration, price, contractWETH.address))
						.to.emit(contract, 'SellOrderBooked')
						.withArgs(account.address, contractERC721.address, 1, expiration, price, contractWETH.address);

					const order = await contract.getSellOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(expiration);
					expect(order[1]).to.be.equal(price);
					expect(order[2]).to.be.equal(contractWETH.address);

					await expect(
						contract
							.connect(buyer)
							.exerciseSellOrder(account.address, contractERC721.address, 1, expiration, price, buyer.address, contractWETH.address)
					)
						.to.emit(contract, 'SellOrderExercised')
						.withArgs(account.address, buyer.address, buyer.address, contractERC721.address, 1, price, contractWETH.address)
						.and.to.emit(contract, 'SellOrderCanceled')
						.withArgs(account.address, contractERC721.address, 1);

					expect((await contractWETH.balanceOf(account.address)).toString()).to.be.equal(
						BigNumber.from(price).sub(BigNumber.from(price).mul(SYSTEM_FEE).div(1000)).toString()
					);

					const canceledOrder = await contract.getSellOrder(account.address, contractERC721.address, 1);
					expect(canceledOrder[0]).to.be.equal(zeroAddress);
				});
			});

			describe('buy', () => {
				it('should create new buy order and cancel order', async () => {
					const [account, seller] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					const expiration = BigNumber.from(timestamp);
					const offer = BigNumber.from('10000000000000000'); // 0.01 ETH

					await expect(contractWETH.connect(account).deposit({ value: offer }))
						.to.emit(contractWETH, 'Deposit')
						.withArgs(account.address, offer);
					await expect(contractWETH.connect(account).approve(contract.address, offer))
						.to.emit(contractWETH, 'Approval')
						.withArgs(account.address, contract.address, offer);

					await contractERC721.mintNext(seller.address);
					await expect(contractERC721.connect(seller).setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(seller.address, contract.address, true);

					await expect(contract.bookBuyOrder(seller.address, contractERC721.address, 1, expiration, offer, zeroAddress))
						.to.emit(contract, 'BuyOrderBooked')
						.withArgs(account.address, seller.address, contractERC721.address, 1, expiration, offer, contractWETH.address);

					const order = await contract.getBuyOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(seller.address);
					expect(order[1]).to.be.equal(contractWETH.address);
					expect(order[2]).to.be.equal(expiration);
					expect(order[3]).to.be.equal(offer);

					await expect(contract.cancelBuyOrder(contractERC721.address, 1))
						.to.emit(contract, 'BuyOrderCanceled')
						.withArgs(account.address, contractERC721.address, 1);

					const canceledOrder = await contract.getBuyOrder(account.address, contractERC721.address, 1);
					expect(canceledOrder[0]).to.be.equal(zeroAddress);
				});

				it('should create new buy order and accept order', async () => {
					const [account, seller, maker] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					const expiration = BigNumber.from(timestamp);
					const offer = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contract.setSystemFeeWallet(maker.address);

					await expect(contractWETH.connect(account).deposit({ value: offer }))
						.to.emit(contractWETH, 'Deposit')
						.withArgs(account.address, offer);
					await expect(contractWETH.connect(account).approve(contract.address, offer))
						.to.emit(contractWETH, 'Approval')
						.withArgs(account.address, contract.address, offer);

					await contractERC721.mintNext(seller.address);

					await expect(contract.connect(account).bookBuyOrder(seller.address, contractERC721.address, 1, expiration, offer, zeroAddress))
						.to.emit(contract, 'BuyOrderBooked')
						.withArgs(account.address, seller.address, contractERC721.address, 1, expiration, offer, contractWETH.address);

					const order = await contract.getBuyOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(seller.address);
					expect(order[1]).to.be.equal(contractWETH.address);
					expect(order[2]).to.be.equal(expiration);
					expect(order[3]).to.be.equal(offer);

					await expect(contractERC721.connect(seller).setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(seller.address, contract.address, true);

					await expect(
						contract.connect(seller).exerciseBuyOrder(account.address, contractERC721.address, 1, expiration, offer, contractWETH.address)
					)
						.to.emit(contract, 'BuyOrderExercised')
						.withArgs(account.address, seller.address, contractERC721.address, 1, offer, contractWETH.address)
						.and.to.emit(contract, 'BuyOrderCanceled')
						.withArgs(account.address, contractERC721.address, 1);

					const canceledOrder = await contract.getBuyOrder(account.address, contractERC721.address, 1);
					expect(canceledOrder[0]).to.be.equal(zeroAddress);
				});
			});
		});
	});

	describe('upgraded v2 mock', () => {
		describe('upgradeability', () => {
			it('should upgrade and check version', async () => {
				const currentVersion = await contract.version();
				const ERC721ExchangeUpgradeableUpgradedContract = await ethers.getContractFactory('ERC721ExchangeUpgradeableUpgraded');
				const contractUpgraded = (await upgrades.upgradeProxy(
					contract.address,
					ERC721ExchangeUpgradeableUpgradedContract
				)) as ERC721ExchangeUpgradeableUpgraded;
				await contractUpgraded.deployed();

				const version = await contractUpgraded.version();

				expect(currentVersion.add(1).toString()).to.equal(version.toString());
			});
		});
	});
});
