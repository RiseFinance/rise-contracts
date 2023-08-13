import { ethers } from "ethers";
import { getContract, Network } from "../utils/getContract";
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

    const arbSys = getContract(
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
      "IOutbox", // FIXME:
      Network.L2,
      true // isPresetAddress
    );

    // ==================== Call Contract Functions ====================
    // note: position, index, leaf have the same value

    const l3GatewayAddress = getContractAddress("L3Gateway");
    const l2MarginGatewayAddress = getContractAddress("L2MarginGateway");

    // const tx = await arbSys.sendMerkleTreeState();

    // FIXME: cannot call ArbSys funcions (only callable by zero address)
    // appchain should maintain a variable to store the latest merkle tree size.

    // TODO: how to get txHash?
    // Retryable Ticket => withdrawAssetToL2
    // get from L3 event logs: while calling submitRetryable, get event log `RedeemScheduled` -> `retryTxHash`

    const txHashSubmitRetryable =
      "0x389a4a851508b7b87e8d934415c9cf2b7e99e926dce0d5bc8aafec84ee168b63"; // 이건 L2MarginGateway.triggerWithdrawalFromL2의 `MessageDelivered.sender` 이벤트 필드로 참조 가능 (from L2)

    const redeemScheduledEvent: RedeemScheduled = (await fetchL3EventLogs(
      txHashSubmitRetryable,
      L3EventType.RedeemScheduled
    )) as RedeemScheduled;

    // txHash for `withdrawAssetToL2` from L3
    const txHashWithdrawAssetToL2 = redeemScheduledEvent.retryTxHash;
    // console.log(">>> retryable txHash: ", txHashWithdrawAssetToL2);

    const l2ToL1TxEvent: L2ToL1Tx = (await fetchL3EventLogs(
      txHashWithdrawAssetToL2,
      L3EventType.L2ToL1Tx
    )) as L2ToL1Tx;

    const size = 10; // TODO: set
    const leaf = l2ToL1TxEvent.position;
    console.log(">>> leaf: ", leaf);
    const merkleProof = (await nodeInterface.constructOutboxProof(size, leaf))
      .proof;

    const redeemTx = await iOutbox.executeTransaction(
      merkleProof,
      l2ToL1TxEvent.position, // index
      l3GatewayAddress, // l2Sender
      l2MarginGatewayAddress, // to
      l2ToL1TxEvent.arbBlockNum, // l2Block
      l2ToL1TxEvent.ethBlockNum, // l1Block
      l2ToL1TxEvent.timestamp, // l2Timestamp
      l2ToL1TxEvent.callvalue, // value
      l2ToL1TxEvent.data, // data
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
