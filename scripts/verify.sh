#!/bin/sh

HERE=$(dirname $(realpath $0))

PRESET_PATH=$HERE/input/presetAddresses.json
CONTRACT_PATH=$HERE/output/contractAddresses.json

L2Network='l2testnet'
L3Network='l3local'

##### Preset #####

inbox=$(jq -r '.inbox' $PRESET_PATH)
keeper=$(jq -r '.keeper' $PRESET_PATH)

##### L2 #####

TestUSDC=$(jq -r '.L2.TestUSDC' $CONTRACT_PATH)
Market=$(jq -r '.L2.Market' $CONTRACT_PATH)
TokenInfo=$(jq -r '.L2.TokenInfo' $CONTRACT_PATH)
L2Vault=$(jq -r '.L2.L2Vault' $CONTRACT_PATH)
L2MarginGateway=$(jq -r '.L2.L2MarginGateway' $CONTRACT_PATH)
RisePoolUtils=$(jq -r '.L2.RisePoolUtils' $CONTRACT_PATH)
L2LiquidityGateway=$(jq -r '.L2.L2LiquidityGateway' $CONTRACT_PATH)

npx hardhat verify --network $L2Network --contract contracts/token/TestUSDC.sol:TestUSDC $TestUSDC
npx hardhat verify --network $L2Network --contract contracts/market/Market.sol:Market $Market
npx hardhat verify --network $L2Network --contract contracts/market/TokenInfo.sol:TokenInfo $TokenInfo "$Market"
npx hardhat verify --network $L2Network --contract contracts/crosschain/L2Vault.sol:L2Vault $L2Vault
npx hardhat verify --network $L2Network --contract contracts/crosschain/L2MarginGateway.sol:L2MarginGateway $L2MarginGateway "$inbox" "$L2Vault" "$TokenInfo"
npx hardhat verify --network $L2Network --contract contracts/risepool/RisePoolUtils.sol:RisePoolUtils $RisePoolUtils
npx hardhat verify --network $L2Network --contract contracts/crosschain/L2LiquidityGateway.sol:L2LiquidityGateway $L2LiquidityGateway "$inbox" "$L2Vault" "$Market" "$RisePoolUtils"


##### L3 #####

TraderVault=$(jq -r '.L3.TraderVault' $CONTRACT_PATH)
Market=$(jq -r '.L3.Market' $CONTRACT_PATH)
TokenInfo=$(jq -r '.L3.TokenInfo' $CONTRACT_PATH)
RisePool=$(jq -r '.L3.RisePool' $CONTRACT_PATH)
GlobalState=$(jq -r '.L3.GlobalState' $CONTRACT_PATH)
L3Gateway=$(jq -r '.L3.L3Gateway' $CONTRACT_PATH)
PriceManager=$(jq -r '.L3.PriceManager' $CONTRACT_PATH)
Funding=$(jq -r '.L3.Funding' $CONTRACT_PATH)
PositionVault=$(jq -r '.L3.PositionVault' $CONTRACT_PATH)
OrderValidator=$(jq -r '.L3.OrderValidator' $CONTRACT_PATH)
OrderHistory=$(jq -r '.L3.OrderHistory' $CONTRACT_PATH)
PositionHistory=$(jq -r '.L3.PositionHistory' $CONTRACT_PATH)
MarketOrder=$(jq -r '.L3.MarketOrder' $CONTRACT_PATH)
OrderBook=$(jq -r '.L3.OrderBook' $CONTRACT_PATH)
OrderRouter=$(jq -r '.L3.OrderRouter' $CONTRACT_PATH)
PriceRouter=$(jq -r '.L3.PriceRouter' $CONTRACT_PATH)

npx hardhat verify --network $L3Network --contract contracts/account/TraderVault.sol:TraderVault $TraderVault
npx hardhat verify --network $L3Network --contract contracts/market/Market.sol:Market $Market
npx hardhat verify --network $L3Network --contract contracts/market/TokenInfo.sol:TokenInfo $TokenInfo "$Market"
npx hardhat verify --network $L3Network --contract contracts/risepool/RisePool.sol:RisePool $RisePool
npx hardhat verify --network $L3Network --contract contracts/global/GlobalState.sol:GlobalState $GlobalState
npx hardhat verify --network $L3Network --contract contracts/crosschain/L3Gateway.sol:L3Gateway $L3Gateway "$TraderVault" "$TokenInfo" "$RisePool" "$Market" "$L2MarginGateway" "$L2LiquidityGateway"
npx hardhat verify --network $L3Network --contract contracts/oracle/PriceManager.sol:PriceManager $PriceManager "$GlobalState" "$TokenInfo"
npx hardhat verify --network $L3Network --contract contracts/fee/Funding.sol:Funding $Funding "$PriceManager" "$GlobalState" "$TokenInfo" "$Market"
npx hardhat verify --network $L3Network --contract contracts/position/PositionVault.sol:PositionVault $PositionVault "$Funding"
npx hardhat verify --network $L3Network --contract contracts/order/OrderValidator.sol:OrderValidator $OrderValidator "$PositionVault" "$GlobalState" "$RisePool"
npx hardhat verify --network $L3Network --contract contracts/order/OrderHistory.sol:OrderHistory $OrderHistory "$TraderVault"
npx hardhat verify --network $L3Network --contract contracts/position/PositionHistory.sol:PositionHistory $PositionHistory "$PositionVault" "$TraderVault"
npx hardhat verify --network $L3Network --contract contracts/order/MarketOrder.sol:MarketOrder $MarketOrder "$TraderVault" "$RisePool" "$Market" "$PositionHistory" "$PositionVault" "$OrderValidator" "$OrderHistory" "$GlobalState"
npx hardhat verify --network $L3Network --contract contracts/orderbook/OrderBook.sol:OrderBook $OrderBook "$TraderVault" "$RisePool" "$Market" "$PositionHIstory" "$PositionVault"
npx hardhat verify --network $L3Network --contract contracts/order/OrderRouter.sol:OrderRouter $OrderRouter "$MarketOrder" "$OrderBook"
npx hardhat verify --network $L3Network --contract contracts/oracle/PriceRouter.sol:PriceRouter $PriceRouter "$PriceManager" "$OrderBook" "$keeper"