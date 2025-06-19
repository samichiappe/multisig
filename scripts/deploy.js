async function main() {
  console.log("🚀 Starting MultisigWallet deployment...\n")

  // Get signers
  const [deployer, owner1, owner2, owner3] = await ethers.getSigners()

  console.log("Deployment Configuration:")
  console.log("Deployer address:", deployer.address)
  console.log("Deployer balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH")

  // Define initial owners (you can modify these addresses)
  const initialOwners = [owner1.address, owner2.address, owner3.address]

  // Define required confirmations
  const requiredConfirmations = 2

  console.log("Multisig Configuration:")
  console.log("Initial owners:", initialOwners)
  console.log("Required confirmations:", requiredConfirmations)

  // Deploy the contract
  console.log("Deploying MultisigWallet...")
  const MultisigWallet = await ethers.getContractFactory("MultisigWallet")
  const multisigWallet = await MultisigWallet.deploy(initialOwners, requiredConfirmations)

  await multisigWallet.waitForDeployment()
  const contractAddress = await multisigWallet.getAddress()

  console.log("MultisigWallet deployed successfully!")
  console.log("Contract address:", contractAddress)

  // Verify deployment
  console.log("Verifying deployment...")
  const owners = await multisigWallet.getOwners()
  const numConfirmations = await multisigWallet.numConfirmationsRequired()

  console.log("✓ Owners:", owners)
  console.log("✓ Required confirmations:", numConfirmations.toString())
  console.log("✓ Transaction count:", (await multisigWallet.getTransactionCount()).toString())

  // Fund the wallet with some ETH for testing (optional)
  if (process.env.FUND_WALLET === "true") {
    console.log("Funding wallet for testing...")
    const fundAmount = ethers.parseEther("1.0")
    const tx = await deployer.sendTransaction({
      to: contractAddress,
      value: fundAmount,
    })
    await tx.wait()

    const balance = await ethers.provider.getBalance(contractAddress)
    console.log("✓ Wallet funded with:", ethers.formatEther(balance), "ETH")
  }

  console.log("Deployment completed successfully!")
  console.log("Next steps:")
  console.log("1. Verify the contract on Etherscan (if on mainnet/testnet)")
  console.log("2. Test the multisig functionality")
  console.log("3. Add more owners if needed using the addOwner function")
  console.log("4. Update the required confirmations if needed")

  // Save deployment info
  const deploymentInfo = {
    contractAddress: contractAddress,
    owners: owners,
    requiredConfirmations: numConfirmations.toString(),
    deploymentBlock: await ethers.provider.getBlockNumber(),
    deploymentTime: new Date().toISOString(),
    network: (await ethers.provider.getNetwork()).name,
  }

  console.log("Deployment Summary:")
  console.log(JSON.stringify(deploymentInfo, null, 2))

  return multisigWallet
}

// Handle errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:")
    console.error(error)
    process.exit(1)
  })
