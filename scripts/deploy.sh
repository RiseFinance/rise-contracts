#!/bin/sh

HERE=$(dirname $(realpath $0))

npx hardhat run $HERE/check_deployer.ts
npx hardhat run $HERE/deploy_libraries.ts --network l3local
npx hardhat run $HERE/deploy_l2.ts --network l2testnet
npx hardhat run $HERE/deploy_l3.ts --network l3local