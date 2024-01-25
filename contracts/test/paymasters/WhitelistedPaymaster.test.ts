import { expect } from 'chai';
import { Contract, Provider, Wallet, utils } from "zksync-ethers";
import * as ethers from "ethers";
import { setupEnv } from './helpers';
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from '../../deploy/utils';

describe("WhitelistPaymaster", function () {
    let paymaster: Contract;
    let flag: Contract;
    let nodl: Contract;

    let adminWallet: Wallet;
    let whitelistAdminWallet: Wallet;
    let withdrawerWallet: Wallet;
    let sponsorWallet: Wallet;
    let userWallet: Wallet;

    let provider: Provider;

    before(async function () {
        adminWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
        whitelistAdminWallet = getWallet(LOCAL_RICH_WALLETS[3].privateKey);
        flag = await deployContract("MockFlag", [], { wallet: adminWallet, silent: true, skipChecks: true });

        const result = await setupEnv("WhitelistPaymaster", [whitelistAdminWallet.address, [await flag.getAddress()]]);
        paymaster = result.paymaster;
        // adminWallet = result.adminWallet;
        withdrawerWallet = result.withdrawerWallet;
        sponsorWallet = result.sponsorWallet;
        userWallet = result.userWallet;
        provider = result.provider;

        nodl = await deployContract("NODL", [adminWallet.address, adminWallet.address], { wallet: adminWallet, silent: true, skipChecks: true });

        // whitelist user
        const whitelistedRole = await paymaster.WHITELISTED_USER_ROLE();
        await paymaster.connect(adminWallet).grantRole(whitelistedRole, userWallet.address, {
            // somehow if we do not do this, the underlying lib will not use an up to date nonce value
            nonce: await adminWallet.getNonce()
        });
    });

    it("Sets correct roles", async () => {
        const adminRole = await paymaster.DEFAULT_ADMIN_ROLE();
        const withdrawerRole = await paymaster.WITHDRAWER_ROLE();
        const whitelistAdminRole = await paymaster.WHITELIST_ADMIN_ROLE();

        expect(await paymaster.hasRole(adminRole, adminWallet.address)).to.be.true;
        expect(await paymaster.hasRole(withdrawerRole, withdrawerWallet.address)).to.be.true;
        expect(await paymaster.hasRole(whitelistAdminRole, whitelistAdminWallet.address)).to.be.true;
    });

    it("Only whitelist admin can update contract whitelist", async function () {
        const newFlag = await deployContract("MockFlag", [], { wallet: withdrawerWallet, silent: true, skipChecks: true });
        const newFlagAddress = await newFlag.getAddress();

        const whitelistAdminRole = await paymaster.WHITELIST_ADMIN_ROLE();

        await expect(
            paymaster.connect(userWallet).addWhitelistedContracts([newFlagAddress])
        ).to.be
            .revertedWithCustomError(paymaster, "AccessControlUnauthorizedAccount")
            .withArgs(userWallet.address, whitelistAdminRole);

        await expect(
            paymaster.connect(userWallet).removeWhitelistedContracts([newFlagAddress])
        ).to.be
            .revertedWithCustomError(paymaster, "AccessControlUnauthorizedAccount")
            .withArgs(userWallet.address, whitelistAdminRole);

        const nonce = await whitelistAdminWallet.getNonce();

        await paymaster.connect(whitelistAdminWallet).addWhitelistedContracts([newFlagAddress], { nonce: nonce });
        expect(await paymaster.isWhitelistedContract(newFlagAddress)).to.be.true;
        expect(await paymaster.isWhitelistedContract(await flag.getAddress())).to.be.true;

        await paymaster.connect(whitelistAdminWallet).removeWhitelistedContracts([newFlagAddress], { nonce: nonce + 1 });
        expect(await paymaster.isWhitelistedContract(newFlagAddress)).to.be.false;
        expect(await paymaster.isWhitelistedContract(await flag.getAddress())).to.be.true;
    });

    it("Does not support approval based flow", async function () {
        const paymasterParams = utils.getPaymasterParams(await paymaster.getAddress(), {
            type: "ApprovalBased",
            token: await nodl.getAddress(),
            minimalAllowance: ethers.toBigInt(0),
            innerInput: new Uint8Array(),
        });

        // bootloader / zksync logic strips our error context away so
        // `.revertedWithCustomError(paymaster, "PaymasterFlowNotSupported");`
        // would not work
        await expect(
            flag.connect(userWallet).setFlag("flag captured", {
                customData: {
                    gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
                    paymasterParams,
                },
            })
        ).to.be.revertedWithoutReason();
    });

    it("Supports calls to whitelisted contracts", async function () {
        const paymasterParams = utils.getPaymasterParams(await paymaster.getAddress(), {
            type: "General",
            innerInput: new Uint8Array(),
        });
        
        await flag.connect(userWallet).setFlag("flag captured", {
            customData: {
                gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
                paymasterParams,
            },
        });

        expect(await flag.flag()).to.equal("flag captured");
    });

    it("Does not support calls to non-whitelisted contracts", async function () {
        const newFlag = await deployContract("MockFlag", [], { wallet: adminWallet, silent: true, skipChecks: true });

        const paymasterParams = utils.getPaymasterParams(await paymaster.getAddress(), {
            type: "General",
            innerInput: new Uint8Array(),
        });

        await expect(
            newFlag.connect(userWallet).setFlag("flag captured", {
                customData: {
                    gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
                    paymasterParams,
                },
            })
        ).to.be.revertedWithoutReason();
    });

    it("Does not support calls from non-whitelisted users", async function () {
        const paymasterParams = utils.getPaymasterParams(await paymaster.getAddress(), {
            type: "General",
            innerInput: new Uint8Array(),
        });

        await expect(
            flag.connect(sponsorWallet).setFlag("flag captured", {
                customData: {
                    gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
                    paymasterParams,
                },
            })
        ).to.be.revertedWithoutReason();
    });
});