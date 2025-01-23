#!/bin/bash
#
# Description:
#   Downloads contract source code from Etherscan for specified L1&L2 contracts
#   that were deployed before the upgrade block on OP Mainnet.
#   This script uses the Etherscan API to fetch verified contract sources
#   and saves them to local files.
#
# Requirements:
#   - curl
#   - jq
#   - cast (Foundry)
#
# Required Environment variables:
#   - L2_UPGRADE_BLOCK: Block number when upgrade was applied on L2(OP Mainnet)
#                       Reference: https://docs.optimism.io/builders/node-operators/network-upgrades
#   - L1_ETHERSCAN_API_KEY: Your Etherscan(L1) API key
#   - L2_ETHERSCAN_API_KEY: Your Etherscan(L2) API key
#
# Optional Environment variables:
#   - SAVE_DIR: Directory where downloaded contract files will be saved
#   - L1_RPC: Ethereum mainnet RPC URL
#   - L2_RPC: OP Mainnet RPC URL
#   - L1_ADDRESS_MANAGER: Address of the AddressManager contract on L1
#
# Usage:
#   bash ./download-etherscan-contract.sh
#


######## Variable Definitions ########
# Required variables
L2_UPGRADE_BLOCK="$L2_UPGRADE_BLOCK"
L1_ETHERSCAN_API_KEY="${L1_ETHERSCAN_API_KEY}"
L2_ETHERSCAN_API_KEY="${L2_ETHERSCAN_API_KEY}"

# Optional variables
SAVE_DIR="${SAVE_DIR:-$(mktemp -d)}"
L1_RPC="${L1_RPC:-https://eth.drpc.org}"
L2_RPC="${L2_RPC:-https://optimism.drpc.org}"
L1_ADDRESS_MANAGER="${L1_ADDRESS_MANAGER:-0xdE1FCfB0851916CA5101820A69b13a4E276bd81F}"

# Etherscan URL
L1_ETHERSCAN_URL="https://etherscan.io"
L2_ETHERSCAN_URL="https://optimistic.etherscan.io"
L1_ETHERSCAN_API_URL="https://api.etherscan.io/api"
L2_ETHERSCAN_API_URL="https://api-optimistic.etherscan.io/api"

# L1&L2 contracts to download source code for
# Format: [Layer][ContractName]:[Address]:[ProxyType]:[NameInAddressManager]
# If [ProxyType] is empty, address is treated as implementation address
# [NameInAddressManager] is only required when ProxyType=ResolvedDelegateProxy
GRANITE_CONTRACTS=(
  # L1
  L1:SuperchainConfig:0x95703e0982140D16f8ebA6d158FccEde42f04a4C:Proxy
  L1:OptimismPortal:0x2d778797049fe9259d947d1ed8e5442226dfb589
  L1:L2OutputOracle:0xdfe97868233d1aa22e815a266982f2cf17685a27:Proxy
  L1:SystemConfig:0x229047fed2591dbec1eF1118d64F7aF3dB9EB290:Proxy
  L1:L1CrossDomainMessenger:0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1:ResolvedDelegateProxy:OVM_L1CrossDomainMessenger
  L1:L1StandardBridge:0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1:L1ChugSplashProxy
  L1:L1ERC721Bridge:0x5a7749f83b81B301cAb5f48EB8516B986DAef23D:Proxy
  # L2
  L2:L2CrossDomainMessenger:0x4200000000000000000000000000000000000007:Proxy
  L2:GasPriceOracle:0x420000000000000000000000000000000000000F:Proxy
  L2:L2StandardBridge:0x4200000000000000000000000000000000000010:Proxy
  L2:SequencerFeeVault:0x4200000000000000000000000000000000000011:Proxy
  L2:OptimismMintableERC20Factory:0x4200000000000000000000000000000000000012:Proxy
  L2:L1BlockNumber:0x4200000000000000000000000000000000000013:Proxy
  L2:L2ERC721Bridge:0x4200000000000000000000000000000000000014:Proxy
  L2:L1Block:0x4200000000000000000000000000000000000015:Proxy
  L2:L2ToL1MessagePasser:0x4200000000000000000000000000000000000016:Proxy
  L2:OptimismMintableERC721Factory:0x4200000000000000000000000000000000000017:Proxy
  L2:ProxyAdmin:0x4200000000000000000000000000000000000018:Proxy
  L2:BaseFeeVault:0x4200000000000000000000000000000000000019:Proxy
  L2:L1FeeVault:0x420000000000000000000000000000000000001A:Proxy
  L2:SchemaRegistry:0x4200000000000000000000000000000000000020:Proxy
  L2:EAS:0x4200000000000000000000000000000000000021:Proxy
)
CONTRACTS="${GRANITE_CONTRACTS[@]}"


# Change directory to `packages/contracts-bedrock`
cd "$(dirname $0)/../../../.."


######## Get L2 upgrade block and corresponding L1 block ########
echo "Fetching L1 block corresponding to L2 upgrade block ($L2_UPGRADE_BLOCK)"
L1_BLOCK_CONTRACT="$(grep L1_BLOCK_ATTRIBUTES src/libraries/Predeploys.sol | cut -d'=' -f2 | egrep -o '\w+')"
L1_UPGRADE_BLOCK="$(cast call --rpc-url $L2_RPC --block $L2_UPGRADE_BLOCK $L1_BLOCK_CONTRACT 'number()(uint64)' | egrep -o '^\d+' || exit 1)"
echo "Successfully fetched L1 block ($L1_UPGRADE_BLOCK)"
echo


######## Download contract code ########
layer_vars_setter() {
  layer="$1"

  if [ "$layer" == "L1" ]; then
    rpc_url="$L1_RPC"
    exp_url="$L1_ETHERSCAN_URL"
    api_url="$L1_ETHERSCAN_API_URL"
    api_key="$L1_ETHERSCAN_API_KEY"
    upgrade_block="$L1_UPGRADE_BLOCK"
  else
    rpc_url="$L2_RPC"
    exp_url="$L2_ETHERSCAN_URL"
    api_url="$L2_ETHERSCAN_API_URL"
    api_key="$L2_ETHERSCAN_API_KEY"
    upgrade_block="$L2_UPGRADE_BLOCK"
  fi
}

# Create output directories
getsourcecode_dir="$SAVE_DIR/getsourcecode"
contract_source_dir="$SAVE_DIR/contract"
getcontractcreation_dir="$SAVE_DIR/getcontractcreation"
mkdir $getsourcecode_dir $contract_source_dir $getcontractcreation_dir 2>/dev/null

i=0
impl_addresses=()
implementations_file="$SAVE_DIR/implementations.txt"
touch "$implementations_file"

for line in ${CONTRACTS[@]}; do
  layer=$(echo $line | cut -d: -f1)
  name=$(echo $line | cut -d: -f2)
  proxy_address=$(echo $line | cut -d: -f3)
  proxy_type=$(echo $line | cut -d: -f4)
  impl_name=$(echo $line | cut -d: -f5)
  response_file="$getsourcecode_dir/$layer/${name}.json"
  sources_dir="$contract_source_dir/$layer/$name"

  layer_vars_setter "$layer"

  mkdir "$(dirname $response_file)" 2>/dev/null
  mkdir -p "$sources_dir" 2>/dev/null

  echo "[$layer] $name"

  echo "Fetching implementation address"
  impl_address="$(grep "$name 0x" $implementations_file | cut -d' ' -f2)"
  if [ "$impl_address" == "" ]; then
    case "$proxy_type" in
      Proxy)
        impl_address="$(cast call --rpc-url $rpc_url --block $upgrade_block $proxy_address 'implementation()(address)')"
        ;;
      L1ChugSplashProxy)
        impl_address="$(cast call --rpc-url $rpc_url --block $upgrade_block $proxy_address 'getImplementation()(address)')"
        ;;
      ResolvedDelegateProxy)
        impl_address="$(cast call --rpc-url $rpc_url --block $upgrade_block $L1_ADDRESS_MANAGER 'getAddress(string)(address)' $impl_name)"
        ;;
      *)
        impl_address="$proxy_address"
    esac
    if [ "$impl_address" == "" ]; then
      echo "Failed fetch address"
      exit 1
    fi
    echo "$name $impl_address" >> $implementations_file
    sleep 1 # Rate limit compliance
  fi
  echo "Successfully fetched address ($exp_url/address/${impl_address})"

  impl_addresses[i]="$impl_address"
  i=$(expr $i + 1)

  echo "Downloading contract code from Etherscan"
  if [ ! -f "$response_file" ] || [ "$(cat $response_file | jq -r .status)" != 1 ]; then
    curl -s --fail -XGET "$api_url" \
      -d apikey="$api_key" \
      -d module=contract \
      -d action=getsourcecode \
      -d address="$impl_address" > "$response_file"
    if [ "$(cat $response_file | jq -r .status)" != 1 ]; then
      echo "Download failed (response saved at: $response_file)"
      exit 1
    fi
    sleep 1 # Rate limit compliance
  fi
  echo "Download successful (response saved at: $response_file)"

  echo "Extracting contract code from response and saving to files"
  cat "$response_file" | jq -r '.result[].SourceCode' | sed 's/^{//;s/}$//' | jq -r '.sources|to_entries[] | "\(.key)\n\(.value)"' | while read -r path; do
    read -r code
    abspath="$sources_dir/$path"
    mkdir -p "$(dirname $abspath)" 2>/dev/null
    echo -n "$code" | jq -jr .content > "$abspath"
    echo "Saved $abspath"
  done

  echo
done


######## Get creation order of implementations ########
# Identify the TX where the implementation contract was created
i=0
for line in ${CONTRACTS[@]}; do
  layer=$(echo $line | cut -d: -f1)
  name=$(echo $line | cut -d: -f2)
  response_file="$getcontractcreation_dir/$layer/${name}.json"

  layer_vars_setter "$layer"

  mkdir "$(dirname $response_file)" 2>/dev/null

  echo "[$layer] $name"

  impl_address="${impl_addresses[$i]}"
  i=$(expr $i + 1)

  echo "Fetching contract creation TX from Etherscan"
  if [ ! -f "$response_file" ] || [ "$(cat $response_file | jq -r .status)" != 1 ]; then
    curl -s --fail -XGET "$api_url" \
      -d apikey="$api_key" \
      -d module=contract \
      -d action=getcontractcreation \
      -d contractaddresses="$impl_address" > "$response_file"
    if [ "$(cat $response_file | jq -r .status)" != 1 ]; then
      echo "Fetch failed (response saved at: $response_file)"
      exit 1
    fi
    sleep 1 # Rate limit compliance
  fi
  echo "Fetch successful (response saved at: $response_file)"
  echo
done

# Identify the block number where the implementation contract was created
for line in ${CONTRACTS[@]}; do
  layer=$(echo $line | cut -d: -f1)
  name=$(echo $line | cut -d: -f2)
  tx_hash="$(cat $getcontractcreation_dir/$layer/${name}.json | jq -r '.result[0].txHash')"
  receipt_file="$SAVE_DIR/creations/$layer/${name}.txt"
  creations_file="$SAVE_DIR/creations-${layer}.txt"

  layer_vars_setter "$layer"

  mkdir -p "$(dirname $receipt_file)" 2>/dev/null
  touch "$creations_file"

  if egrep -q "$name (0x|GENESIS)" "$creations_file"; then
    continue
  fi

  echo "[$layer] $name"

  if echo "$tx_hash" | grep -q 'GENESIS'; then
    echo "This contract was created in the Genesis block"
    echo "$name $tx_hash 0" >> $creations_file
    echo
    continue
  fi

  echo "Fetching receipt of contract creation TX"
  if [ ! -s "$receipt_file" ]; then
    if ! cast receipt --rpc-url "$rpc_url" --async "$tx_hash" > $receipt_file; then
      echo "Fetch failed"
      exit 1
    fi
    sleep 1 # Rate limit compliance
  fi
  echo "Fetch successful"

  confirmed_block="$(cat $receipt_file | grep -i ^blockNumber | egrep -o '\d+')"
  echo "$name $tx_hash $confirmed_block" >> $creations_file

  echo
done
