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
