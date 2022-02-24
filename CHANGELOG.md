# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

## [1.6.0](https://github.com/shibuidao/exchange/compare/v1.5.2...v1.6.0) (2022-02-24)


### Features

* only allow certain structures for keepers ([692eadc](https://github.com/shibuidao/exchange/commit/692eadc811e1aed947f655b9cfd2dfd0346b4257))

### [1.5.2](https://github.com/shibuidao/exchange/compare/v1.5.1...v1.5.2) (2022-02-21)


### Bug Fixes

* pass deployer address as parameter in deploy script ([008c93f](https://github.com/shibuidao/exchange/commit/008c93f49de7a767419f9bac10a882964f7f5bf2))

### [1.5.1](https://github.com/shibuidao/exchange/compare/v1.5.0...v1.5.1) (2022-02-21)

## [1.5.0](https://github.com/shibuidao/exchange/compare/v1.4.0...v1.5.0) (2022-02-21)


### Features

* add diagrams ([5c1d566](https://github.com/shibuidao/exchange/commit/5c1d56699a253f5037cb5fc3fd9698dc485a4ed3))

## [1.4.0](https://github.com/shibuidao/exchange/compare/v1.3.3...v1.4.0) (2022-02-21)


### Features

* provide fee wallet at initialization ([b5d1b47](https://github.com/shibuidao/exchange/commit/b5d1b470917ec5d6e3edb41eea33c0fe4b78e182))

### [1.3.3](https://github.com/shibuidao/exchange/compare/v1.3.2...v1.3.3) (2022-02-21)

### [1.3.2](https://github.com/shibuidao/exchange/compare/v1.3.1...v1.3.2) (2022-02-20)


### Bug Fixes

* remove custom errors ([6096cf2](https://github.com/shibuidao/exchange/commit/6096cf20850a42f44cb2b83ae67940c036d4254c))

### [1.3.1](https://github.com/shibuidao/exchange/compare/v1.3.0...v1.3.1) (2022-02-13)

## [1.3.0](https://github.com/shibuidao/exchange/compare/v1.2.8...v1.3.0) (2022-02-13)


### Features

* allow listings using erc20 tokens ([2080e96](https://github.com/shibuidao/exchange/commit/2080e966ebbc2ec8935bcf947fad87cf5f9d7684))
* base for external order book ([424f21f](https://github.com/shibuidao/exchange/commit/424f21f85b77fe13f7f7d03ffccc1d2c6ec97e62))
* compare order from stored bytes ([2aeefa2](https://github.com/shibuidao/exchange/commit/2aeefa2a3607db196f8a5ceb757bc5d7533f8bb8))
* create script to deploy exchange ([c5f3e5d](https://github.com/shibuidao/exchange/commit/c5f3e5d6a3b2195badf8fc83460025948c78cc0d))
* emit raw events on order book ([416d994](https://github.com/shibuidao/exchange/commit/416d9940d4076373956bdbaf8b92eecf1d77feb9))
* implement new onchain stuff to tests ([c26a2d1](https://github.com/shibuidao/exchange/commit/c26a2d133bee6571688ce369c30534a311f607d4))
* implement sunsetting ([f68b98f](https://github.com/shibuidao/exchange/commit/f68b98f83f6280b95add7685b04b5c60786acbe8))
* test for balance change in eth ([dab970f](https://github.com/shibuidao/exchange/commit/dab970fd9694e33dc2529343a2db6946ba3cb729))
* use external order book in exchange ([6971df4](https://github.com/shibuidao/exchange/commit/6971df405df3c292caac039cfab5f99ee6cdc697))
* use royaltyengine for royalties ([ab91240](https://github.com/shibuidao/exchange/commit/ab91240f4adf4b2e5f7f30d037078b76b72bad47))

### [1.2.8](https://github.com/shibuidao/exchange/compare/v1.2.7...v1.2.8) (2022-01-25)

### [1.2.7](https://github.com/shibuidao/exchange/compare/v1.2.6...v1.2.7) (2022-01-25)


### Bug Fixes

* dont cancel on incorrect params ([ec3ad15](https://github.com/shibuidao/exchange/commit/ec3ad15a43f281657a012fff8ab1105e039f4809))
* move to standard encode over packed ([469f8f6](https://github.com/shibuidao/exchange/commit/469f8f6fbf8df24cd85c648638cddca65145b72d))

### [1.2.6](https://github.com/shibuidao/exchange/compare/v1.2.5...v1.2.6) (2022-01-25)


### Bug Fixes

* clone submodules with actions ([5af18ab](https://github.com/shibuidao/exchange/commit/5af18ab66945b6fc4f36f1a2ee8421cce186dc5f))

### [1.2.5](https://github.com/shibuidao/exchange/compare/v1.2.4...v1.2.5) (2022-01-24)

### [1.2.4](https://github.com/shibuidao/exchange/compare/v1.2.3...v1.2.4) (2022-01-24)

### [1.2.3](https://github.com/shibuidao/exchange/compare/v1.2.2...v1.2.3) (2022-01-24)


### Bug Fixes

* specify upload needs ([a7c1c63](https://github.com/shibuidao/exchange/commit/a7c1c63a2244a890f89210192c9a84b51d87e352))

### [1.2.2](https://github.com/shibuidao/exchange/compare/v1.2.1...v1.2.2) (2022-01-24)


### Bug Fixes

* add name ([d7bdd17](https://github.com/shibuidao/exchange/commit/d7bdd1719fb53908737be176186a2105e8d98e98))
* source bash rc file ([0806baf](https://github.com/shibuidao/exchange/commit/0806baf0d221fa6ea746085cb13bd5941ce04146))

### [1.2.1](https://github.com/shibuidao/exchange/compare/v1.2.0...v1.2.1) (2022-01-23)

## [1.2.0](https://github.com/shibuidao/exchange/compare/v1.1.2...v1.2.0) (2022-01-23)


### Features

* create interface for Foundry cheat codes ([cdd6b1d](https://github.com/shibuidao/exchange/commit/cdd6b1d45f3f7aedb5b9913fbf7ddf85af031218))
* switch tests to forge ([5bca3e1](https://github.com/shibuidao/exchange/commit/5bca3e19308dc8d6b72df8dc6ab0dd21e7e6ef41))


### Bug Fixes

* remove non-standard character ([3ec9fd1](https://github.com/shibuidao/exchange/commit/3ec9fd14db76f95ae70a80a5b48aef0ccac7d852))

### [1.1.2](https://github.com/shibuidao/exchange/compare/v1.1.1...v1.1.2) (2022-01-23)

### [1.1.1](https://github.com/shibuidao/exchange/compare/v1.1.0...v1.1.1) (2022-01-23)


### Bug Fixes

* dont sent system fees to burn address ([3365a50](https://github.com/shibuidao/exchange/commit/3365a5053fcda9d441b947a11a8b8b76dc088c30))

## 1.1.0 (2022-01-22)


### Features

* add buy orders aka bid updating ([f209fd6](https://github.com/shibuidao/exchange/commit/f209fd683692279eb3ecf2b10336917c7b283a9f))
* add tests ([ca2cdab](https://github.com/shibuidao/exchange/commit/ca2cdabd06ed142d93fc64a199f2cf2959ed0c44))
* automatic NPM publishing ([fbeb5bb](https://github.com/shibuidao/exchange/commit/fbeb5bbd656f5b6b06901760cac5d4b6a4544b39))
* basic sell creation and execution tests ([6180884](https://github.com/shibuidao/exchange/commit/61808844bfc35482a299a2ae7cfe071ff8c09fbc))
* basic solidity based test ([5353b84](https://github.com/shibuidao/exchange/commit/5353b84336de4b98f594469f621c4d6328786474))
* buy orders ([9438727](https://github.com/shibuidao/exchange/commit/943872780f746ab20752479d5c073b6dadf91b2c))
* collection royalties ([aa43240](https://github.com/shibuidao/exchange/commit/aa432401890db49e81656cf81f841d83a65ff361))
* contract locking ([0837032](https://github.com/shibuidao/exchange/commit/0837032e637a6f3f7d9c051a9e115ade43466b85))
* rudimentary sell order creation ([7b34555](https://github.com/shibuidao/exchange/commit/7b345550747a85603cbf155e12d29641cc156d0a))
* rudimentary sell order execution ([da35130](https://github.com/shibuidao/exchange/commit/da3513035d6271b85586ef39c10418949530205b))
* run node and hardhat tests in sequence ([559a5c3](https://github.com/shibuidao/exchange/commit/559a5c3f6db4331b6f1c3924adb702316baa15da))
* sell order updating/replacing ([1059e09](https://github.com/shibuidao/exchange/commit/1059e092ee5a5cdc894b8e94d22beda483a34734))
* store weth interface ([d7fe99c](https://github.com/shibuidao/exchange/commit/d7fe99cd1e94053a1b8d054e8148df58211738fe))
* system fees ([cdab5cf](https://github.com/shibuidao/exchange/commit/cdab5cf45ccf83ddaa0df42348d6dc0eeb79649f))
* template ([33f57fe](https://github.com/shibuidao/exchange/commit/33f57fe792b5ee8699ada10bfbf0c116fb92ba95))
* test upgraded contracts ([a6ec270](https://github.com/shibuidao/exchange/commit/a6ec270a55af6f32ae0d51d7ee29a2f3eb8034c9))
* testnet deploy ([19f61a8](https://github.com/shibuidao/exchange/commit/19f61a85b168ef235b092e71f6903ac55e8dfdd3))
* upgradeable contract ([c73cb3f](https://github.com/shibuidao/exchange/commit/c73cb3fac8f4d9c38b6cb7a6a0815bcd2a32dc15))


### Bug Fixes

* add missing internal call ([469c093](https://github.com/shibuidao/exchange/commit/469c09378d4926d9db9489873e492dcf8ae68a04))
* assorted workflow related misshaps ([3c3a459](https://github.com/shibuidao/exchange/commit/3c3a459a595e50ddb0000fbc90e2ddcabe440c35))
