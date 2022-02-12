import chai, { expect } from 'chai';
import { solidity } from 'ethereum-waffle';
import { BigNumber } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import { zeroAddress } from '../constants.hardhat';
import type { ERC721ExchangeUpgradeable, ERC721ExchangeUpgradeableUpgraded, TestERC721, WETHMock } from '../typechain';

chai.use(solidity);

describe('ERC721Exchange', () => {
	let contractWETH: WETHMock;
	let contract: ERC721ExchangeUpgradeable;
	let contractERC721: TestERC721;

	beforeEach(async () => {
		const WETHContract = await ethers.getContractFactory('WETHMock');
		contractWETH = (await WETHContract.deploy()) as WETHMock;

		const ERC721ExchangeUpgradeableContract = await ethers.getContractFactory('ERC721ExchangeUpgradeable');
		contract = (await upgrades.deployProxy(ERC721ExchangeUpgradeableContract, [300, 29, contractWETH.address], {
			initializer: '__ERC721Exchange_init',
			kind: 'transparent'
		})) as ERC721ExchangeUpgradeable;
		await contract.deployed();

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
				it('should create new sell order', async () => {
					const [account] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					const expiration = BigNumber.from(timestamp);
					const price = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contractERC721.mintNext(account.address);
					await expect(contractERC721.setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(account.address, contract.address, true);

					await expect(contract.bookSellOrder(contractERC721.address, 1, expiration, price))
						.to.emit(contract, 'SellOrderBooked')
						.withArgs(account.address, contractERC721.address, 1, expiration, price);

					const order = await contract.getSellOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(expiration);
					expect(order[1]).to.be.equal(price);
				});

				it('should create new sell order and cancel order', async () => {
					const [account] = await ethers.getSigners();
					const timestamp = new Date().getTime() * 2;

					const expiration = BigNumber.from(timestamp);
					const price = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contractERC721.mintNext(account.address);
					await expect(contractERC721.setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(account.address, contract.address, true);

					await expect(contract.bookSellOrder(contractERC721.address, 1, expiration, price))
						.to.emit(contract, 'SellOrderBooked')
						.withArgs(account.address, contractERC721.address, 1, expiration, price);

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

					const expiration = BigNumber.from(timestamp);
					const price = BigNumber.from('10000000000000000'); // 0.01 ETH

					await contractERC721.mintNext(account.address);
					await expect(contractERC721.setApprovalForAll(contract.address, true))
						.to.emit(contractERC721, 'ApprovalForAll')
						.withArgs(account.address, contract.address, true);

					await expect(contract.bookSellOrder(contractERC721.address, 1, expiration, price))
						.to.emit(contract, 'SellOrderBooked')
						.withArgs(account.address, contractERC721.address, 1, expiration, price);

					const order = await contract.getSellOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(expiration);
					expect(order[1]).to.be.equal(price);

					await contract.setSystemFeeWallet(maker.address);

					await expect(
						contract
							.connect(buyer)
							.exerciseSellOrder(account.address, contractERC721.address, 1, expiration, price, buyer.address, { value: price })
					)
						.to.emit(contract, 'SellOrderExercised')
						.withArgs(account.address, buyer.address, buyer.address, contractERC721.address, 1, price)
						.and.to.emit(contract, 'SellOrderCanceled')
						.withArgs(account.address, contractERC721.address, 1);

					const canceledOrder = await contract.getSellOrder(account.address, contractERC721.address, 1);
					expect(canceledOrder[0]).to.be.equal(zeroAddress);
				});
			});

			describe('buy', () => {
				it('should create new buy order', async () => {
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

					await expect(contract.bookBuyOrder(seller.address, contractERC721.address, 1, expiration, offer))
						.to.emit(contract, 'BuyOrderBooked')
						.withArgs(account.address, seller.address, contractERC721.address, 1, expiration, offer);

					const order = await contract.getBuyOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(seller.address);
					expect(order[1]).to.be.equal(expiration);
					expect(order[2]).to.be.equal(offer);
				});

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

					await expect(contract.bookBuyOrder(seller.address, contractERC721.address, 1, expiration, offer))
						.to.emit(contract, 'BuyOrderBooked')
						.withArgs(account.address, seller.address, contractERC721.address, 1, expiration, offer);

					const order = await contract.getBuyOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(seller.address);
					expect(order[1]).to.be.equal(expiration);
					expect(order[2]).to.be.equal(offer);

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

					await expect(contract.bookBuyOrder(seller.address, contractERC721.address, 1, expiration, offer))
						.to.emit(contract, 'BuyOrderBooked')
						.withArgs(account.address, seller.address, contractERC721.address, 1, expiration, offer);

					const order = await contract.getBuyOrder(account.address, contractERC721.address, 1);

					expect(order[0]).to.be.equal(seller.address);
					expect(order[1]).to.be.equal(expiration);
					expect(order[2]).to.be.equal(offer);

					await contract.setSystemFeeWallet(maker.address);

					await expect(contract.connect(seller).exerciseBuyOrder(account.address, contractERC721.address, 1, expiration, offer))
						.to.emit(contract, 'BuyOrderExercised')
						.withArgs(account.address, seller.address, contractERC721.address, 1, offer)
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
