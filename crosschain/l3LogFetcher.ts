import { ethers } from "ethers";

export enum L3EventType {
  L2ToL1Tx = "L2ToL1Tx", // from function call `withdrawAssetToL2`
  RedeemScheduled = "RedeemScheduled", // from function call `submitRetryable`
}

// Topic0 = signature of the event
enum Topic0 {
  L2ToL1Tx = "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc", // event: `L2ToL1Tx`
  RedeemScheduled = "0x5ccd009502509cf28762c67858994d85b163bb6e451f5e9df7c5e18c9c2e123e", // event: `RedeemScheduled`
}

enum EventABI {
  L2ToL1Tx = "event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)",
  RedeemScheduled = "event RedeemScheduled(bytes32 indexed ticketId, bytes32 indexed retryTxHash, uint64 indexed sequenceNum, uint64 donatedGas, address gasDonor, uint256 maxRefund, uint256 submissionFeeRefund)",
}

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

export interface RedeemScheduled {
  ticketId: string;
  retryTxHash: string;
  sequenceNum: string;
  donatedGas: string;
  gasDonor: string;
  maxRefund: string;
  submissionFeeRefund: string;
}

export async function fetchL3EventLogs(
  txHash: string,
  l3EventType: L3EventType
) {
  const l3Provider = new ethers.providers.JsonRpcProvider(
    "http://localhost:8449"
  );
  const txReceipt = await l3Provider.getTransactionReceipt(txHash);

  // iterate txRecipt.logs
  let data: string = "0x";
  let topics: readonly string[] = ["0x"];
  let topic0: string;
  let iface: ethers.utils.Interface;
  let logObject: L2ToL1Tx | RedeemScheduled = {} as L2ToL1Tx | RedeemScheduled;

  // select topic0 and iface for different l3 event types
  if (l3EventType === L3EventType.L2ToL1Tx) {
    topic0 = Topic0.L2ToL1Tx;
    iface = new ethers.utils.Interface([EventABI.L2ToL1Tx]);
  } else if (l3EventType === L3EventType.RedeemScheduled) {
    topic0 = Topic0.RedeemScheduled;
    iface = new ethers.utils.Interface([EventABI.RedeemScheduled]);
  } else {
    throw new Error("Invalid L3EventType");
  }

  for (let i = 0; i < txReceipt.logs.length; i++) {
    if (txReceipt.logs[i].topics[0] === topic0) {
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
  const log = iface.decodeEventLog(l3EventType, data, topics);

  // convert the `log` array into log object
  if (l3EventType === L3EventType.L2ToL1Tx) {
    logObject = {
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
  } else if (l3EventType === L3EventType.RedeemScheduled) {
    logObject = {
      ticketId: log[0],
      retryTxHash: log[1],
      sequenceNum: log[2],
      donatedGas: log[3],
      gasDonor: log[4],
      maxRefund: log[5],
      submissionFeeRefund: log[6],
    };
  }

  console.log(">>> L3LogFetcher: ", logObject);

  return logObject;
}
