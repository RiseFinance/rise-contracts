#!/bin/sh


HERE=$(dirname $(realpath $0))

sh $HERE/deploy.sh

sh $HERE/initialize.sh
sh $HERE/verify.sh

ts-node $HERE/../rpc/l2_balances.ts
ts-node $HERE/../rpc/l3_balances.ts

ts-node $HERE/../crosschain/approveUSDC.ts
ts-node $HERE/../crosschain/deposit.ts

ts-node $HERE/../rpc/l2_balances.ts
# wait for 3 minutes...
sleep 3m
ts-node $HERE/../rpc/l3_balances.ts
