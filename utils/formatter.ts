import { ethers } from "ethers";

export function formatStruct(struct: any) {
  if (struct === undefined) {
    return undefined;
  }
  const result: any = {};
  const keys = Object.keys(struct);
  const N = keys.length / 2;
  for (let i = 0; i < N; i++) {
    const key = keys[i + N];
    const value = struct[key];
    result[key] = value;
  }

  return result;
}

const ETH_DECIMAL = 18;
const USD_DECIMAL = 20;
const USDC_DECIMAL = 20; // FIXME:
const PRICE_BUFFER_DECIMAL = 20;
const FUNDING_RATE_DECIMAL = 26;

enum OrderType {
  Market,
  Limit,
  StopMarket,
  StopLimit,
}

// FIXME: string or number
type OpenPosition = {
  trader: string;
  isLong: boolean;
  unrealizedPnl: string;
  currentPositionRecordId: number;
  marketId: number;
  size: string;
  margin: string;
  avgOpenPrice: string;
  lastUpdatedTime: number;
  avgEntryFundingIndex: string; // int256
};

type OrderRecord = {
  orderType: OrderType;
  isLong: boolean;
  isIncrease: boolean;
  positionRecordId: number;
  marketId: number;
  sizeAbs: string;
  marginAbs: string;
  executionPrice: string;
  timestamp: number;
};

type PositionRecord = {
  isClosed: boolean;
  cumulativeRealizedPnl: string;
  cumulativeClosedSize: string;
  marketId: number;
  maxSize: number;
  avgOpenPrice: string;
  avgClosePrice: string;
  openTimestamp: number;
  closeTimestamp: number;
};

type GlobalPositionState = {
  totalSize: string;
  totalMargin: string;
  avgPrice: string;
};

export function formatPosition(struct: any) {
  struct = formatStruct(struct);
  struct.unrealizedPnl = ethers.utils.formatUnits(
    struct.unrealizedPnl,
    USD_DECIMAL
  ); // FIXME: check if USD or tokenCount
  struct.currentPositionRecordId = struct.currentPositionRecordId.toNumber();
  struct.marketId = struct.marketId.toNumber();
  struct.size = ethers.utils.formatUnits(struct.size, ETH_DECIMAL);
  struct.margin = ethers.utils.formatUnits(struct.margin, ETH_DECIMAL);
  struct.avgOpenPrice = ethers.utils.formatUnits(
    struct.avgOpenPrice,
    USD_DECIMAL
  );
  struct.lastUpdatedTime = struct.lastUpdatedTime.toNumber();
  struct.avgEntryFundingIndex = ethers.utils.formatUnits(
    struct.avgEntryFundingIndex,
    PRICE_BUFFER_DECIMAL
  );

  return struct as OpenPosition;
}

export function formatOrderRecord(struct: any) {
  struct = formatStruct(struct);

  struct.orderType = OrderType[struct.orderType];
  struct.positionRecordId = struct.positionRecordId.toNumber();
  struct.marketId = struct.marketId.toNumber();
  struct.sizeAbs = ethers.utils.formatUnits(struct.sizeAbs, ETH_DECIMAL);
  struct.marginAbs = ethers.utils.formatUnits(struct.marginAbs, ETH_DECIMAL);
  struct.executionPrice = ethers.utils.formatUnits(
    struct.executionPrice,
    USD_DECIMAL
  );
  struct.timestamp = struct.timestamp.toNumber();

  return struct as OrderRecord;
}

export function formatPositionRecord(struct: any) {
  struct = formatStruct(struct);

  struct.cumulativeRealizedPnl = ethers.utils.formatUnits(
    struct.cumulativeRealizedPnl,
    USD_DECIMAL
  );
  struct.cumulativeClosedSize = ethers.utils.formatUnits(
    struct.cumulativeClosedSize,
    ETH_DECIMAL
  );
  struct.marketId = struct.marketId.toNumber();
  struct.maxSize = ethers.utils.formatUnits(struct.maxSize, ETH_DECIMAL);
  struct.avgOpenPrice = ethers.utils.formatUnits(
    struct.avgOpenPrice,
    USD_DECIMAL
  );
  struct.avgClosePrice = ethers.utils.formatUnits(
    struct.avgClosePrice,
    USD_DECIMAL
  );
  struct.openTimestamp = struct.openTimestamp.toNumber();
  struct.closeTimestamp = struct.closeTimestamp.toNumber();

  return struct as PositionRecord;
}

export function formatGlobalPositionState(struct: any) {
  struct = formatStruct(struct);

  struct.totalSize = ethers.utils.formatUnits(struct.totalSize, ETH_DECIMAL);
  struct.totalMargin = ethers.utils.formatUnits(
    struct.totalMargin,
    ETH_DECIMAL
  );
  struct.avgPrice = ethers.utils.formatUnits(struct.avgPrice, USD_DECIMAL);

  return struct as GlobalPositionState;
}

export function formatUSDC(value: any) {
  return ethers.utils.formatUnits(value, USDC_DECIMAL);
}

export function formatETH(value: any) {
  return ethers.utils.formatUnits(value, ETH_DECIMAL);
}
