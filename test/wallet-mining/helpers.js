// Helper function to deploy a contract using a raw transaction
const deployContract = async (rawTransaction) => {
  const txResponse = await ethers.provider.sendTransaction(rawTransaction);
  const txReceipt = await txResponse.wait();
  return txReceipt.contractAddress;
};

// Helper function to create ABIs
const createInterface = (signature, methodName, arguments) => {
  const ABI = signature;
  const IFace = new ethers.utils.Interface(ABI);
  const ABIData = IFace.encodeFunctionData(methodName, arguments);
  return ABIData;
};

// Helper function to find the nonce for a given address
const findNonceForAddress = (senderAddress, targetAddress) => {
  let nonce = 0;
  let address = ""; // Make sure the created address equals the target address

  while (address.toLowerCase() != targetAddress.toLowerCase()) {
    address = ethers.utils.getContractAddress({
      from: senderAddress,
      nonce: nonce,
    });
    nonce++;
  }

  console.log("Nonce required: ", nonce);
  return nonce;
};

module.exports = { deployContract, createInterface, findNonceForAddress };
