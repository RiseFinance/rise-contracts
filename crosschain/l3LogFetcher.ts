import { ethers } from "ethers";

export interface L2ToL1Tx {
  caller: string;
  destination: string;
  hash: string;
  position: string;
  arbBlockNum: string;
  ethBlockNum: string;
  timestamp: string;
  callvalue: string;
  data: string;
}

export async function fetchL3EventLogs(txHash: string) {
  const l3Provider = new ethers.providers.JsonRpcProvider(
    "http://localhost:8449"
  );

  const txReceipt = await l3Provider.getTransactionReceipt(txHash);

  // iterate txRecipt.logs

  let data: string = "0x";
  let topics: readonly string[] = ["0x"];

  for (let i = 0; i < txReceipt.logs.length; i++) {
    if (
      txReceipt.logs[i].topics[0] ===
      "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc" // method: `L2ToL1Tx`
    ) {
      data = txReceipt.logs[i].data;
      topics = txReceipt.logs[i].topics;
      break;
    } else {
      data = "0x";
      topics = ["0x"];
      continue;
    }
  }

  /// common
  const iface = new ethers.utils.Interface([
    "event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)",
  ]);
  const log = iface.decodeEventLog("L2ToL1Tx", data, topics);

  // convert the `log` array into L2ToL1Tx object
  const l2ToL1Tx: L2ToL1Tx = {
    caller: log[0],
    destination: log[1],
    hash: log[2],
    position: log[3],
    arbBlockNum: log[4],
    ethBlockNum: log[5],
    timestamp: log[6],
    callvalue: log[7],
    data: log[8],
  };

  return l2ToL1Tx;
}

// async function main() {
//   try {
//     // ---------------------------------------------------------------------------------------

//     /// option 1. Log로 조회하기

//     // Warning
//     // Get event logs for an address and/or topics. Up to a maximum of 1,000 event logs.
//     // const apiUrl = "http://localhost:4000/api";

//     // const client: Axios = axios.create({
//     //   baseURL: apiUrl,
//     //   headers: {
//     //     "Content-Type": "application/json",
//     //   },
//     // });

//     // const params = {
//     //   module: "logs",
//     //   action: "getLogs",
//     //   fromBlock: 17, // TODO: set
//     //   toBlock: 17,
//     //   address: "0x0000000000000000000000000000000000000064",
//     //   topic0:
//     //     "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc", // method: `L2ToL1Tx`
//     // };

//     // // const response = await client.get("/", { params });
//     // const response = await axios.get(apiUrl, { params });
//     // const data = response.data.result[0].data;
//     // const topics = response.data.result[0].topics;

//     // ---------------------------------------------------------------------------------------

//     /// option 2. 트랜잭션 Receipt로 조회하기

//     const txHash =
//       "0x491dd5f3850efff43ede54e2d4579ef082f512f2fe5dbb110cffa158e7c8b55f";

//     const l3Provider = new ethers.providers.JsonRpcProvider(
//       "http://localhost:8449"
//     );

//     const txReceipt = await l3Provider.getTransactionReceipt(txHash);
//     const data = txReceipt.logs[0].data;
//     const topics = txReceipt.logs[0].topics;

//     /// common
//     const iface = new ethers.utils.Interface([
//       "event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)",
//     ]);
//     const log = iface.decodeEventLog("L2ToL1Tx", data, topics);

//     // convert the `log` array into L2ToL1Tx object
//     const l2ToL1Tx: L2ToL1Tx = {
//       caller: log[0],
//       destination: log[1],
//       hash: log[2],
//       position: log[3],
//       arbBlockNum: log[4],
//       ethBlockNum: log[5],
//       timestamp: log[6],
//       callvalue: log[7],
//       data: log[8],
//     };

//     return l2ToL1Tx;
//   } catch (error) {
//     console.log(error);
//   }
// }

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
