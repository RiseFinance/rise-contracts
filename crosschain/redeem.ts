import { ethers } from "ethers";
import {
  getContract,
  getReadonlyContract,
  Network,
} from "../utils/getContract";
import { getContractAddress } from "../utils/getContractAddress";
import {
  fetchL3EventLogs,
  L3EventType,
  L2ToL1Tx,
  RedeemScheduled,
} from "./l3LogFetcher";

async function main() {
  try {
    // ========================= Set Contract  =========================

    const arbSys = getReadonlyContract(
      "crosschain/interfaces/l3",
      "ArbSys",
      Network.L3,
      true // isPresetAddress
    );

    const nodeInterface = getContract(
      "crosschain/interfaces/l3",
      "NodeInterface",
      Network.L3,
      true // isPresetAddress
    );

    const iOutbox = getContract(
      "crosschain/interfaces/l2",
      "IOutbox", // FIXME: name
      Network.L2,
      true // isPresetAddress
    );

    // ==================== Call Contract Functions ====================
    // note: position, index, leaf have the same value

    const l3GatewayAddress = getContractAddress("L3Gateway");
    const l2MarginGatewayAddress = getContractAddress("L2MarginGateway");

    // TODO: how to get txHash?
    // function calls: submitRetryable => withdrawAssetToL2
    // get from L3 event logs: while calling submitRetryable, get event log `RedeemScheduled` -> `retryTxHash`

    // TODO: set
    // We can get the L3 sender address from
    // L2MarginGateway.triggerWithdrawalFromL2's `MessageDelivered.sender` event field (from L2)
    const submitRetryableTxHash =
      "0x389a4a851508b7b87e8d934415c9cf2b7e99e926dce0d5bc8aafec84ee168b63";

    const redeemScheduledEventLog: RedeemScheduled = (await fetchL3EventLogs(
      submitRetryableTxHash,
      L3EventType.RedeemScheduled
    )) as RedeemScheduled;

    // txHash for `withdrawAssetToL2` from L3
    const withdrawAssetToL2TxHash = redeemScheduledEventLog.retryTxHash;

    const l2ToL1TxEventLog: L2ToL1Tx = (await fetchL3EventLogs(
      withdrawAssetToL2TxHash,
      L3EventType.L2ToL1Tx
    )) as L2ToL1Tx;

    const sendMerkleTreeSize = (await arbSys.sendMerkleTreeState()).size;
    const leaf = l2ToL1TxEventLog.position;

    // construct a mekle proof for the leaf via the nodeInterface virtual contract interface
    const merkleProof = (
      await nodeInterface.constructOutboxProof(sendMerkleTreeSize, leaf)
    ).proof;

    const redeemTx = await iOutbox.executeTransaction(
      merkleProof,
      l2ToL1TxEventLog.position, // index
      l3GatewayAddress, // l2Sender
      l2MarginGatewayAddress, // to
      l2ToL1TxEventLog.arbBlockNum, // l2Block
      l2ToL1TxEventLog.ethBlockNum, // l1Block
      l2ToL1TxEventLog.timestamp, // l2Timestamp
      l2ToL1TxEventLog.callvalue, // value
      l2ToL1TxEventLog.data, // data
      { gasLimit: ethers.BigNumber.from("30000000") }
    );

    redeemTx.wait();

    console.log(">>> redeemTx: ", redeemTx);

    // =================================================================
  } catch (e) {
    console.log(e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
