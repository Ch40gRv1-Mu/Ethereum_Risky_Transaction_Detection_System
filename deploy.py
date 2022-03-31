from solcx import compile_standard, install_solc
import json
from web3 import Web3
import random
with open("./RTDS.sol", "r") as file:
    safe_wallet_file = file.read()


# Number of transactions
NUMBER_OF_TRANSACTIONS_BEFORE_COMPROMISE = 10
NUMBER_OF_TRANSACTIONS_AFTER_COMPROMISE = 200
# Set the experiement deterministic
random.seed(10)

# Compile the solidity
install_solc("0.8.7")
compiled_sol = compile_standard(
    {
        "language": "Solidity",
        "sources": {"RTDS.sol": {"content": safe_wallet_file}},
        "settings": {
            "outputSelection": {
                "*": {"*": ["abi", "metadata", "evm.bytecode", "evm.sourceMap"]}
            }
        },
    },
    solc_version="0.8.7",
)

with open("compiled_code.json", "w") as file:
    json.dump(compiled_sol, file)

# get bytecode version
bytecode = compiled_sol["contracts"]["RTDS.sol"]["RTDS"]["evm"]["bytecode"]["object"]

# get abi
abi = compiled_sol["contracts"]["RTDS.sol"]["RTDS"]["abi"]

# connect to ganache
w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
chain_id = 1337
my_address = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
private_key = "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"

other_addresses = ["0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
                   "0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b",
                   "0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d",
                   "0xd03ea8624C8C5987235048901fB614fDcA89b117",
                   "0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC",
                   "0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9",
                   "0x28a8746e75304c0780E011BEd21C72cD78cd535E",
                   "0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E",
                   "0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e"
                   ]
other_private_keys = [
    "0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1",
    "0x6370fd033278c143179d81c5526140625662b8daa446c22ee2d73db3707e620c",
    "0x646f1ce2fdad0e6deeeb5c7e8e5543bdde65e86029e2fd9fc169899c440a7913",
    "0xadd53f9a7e588d003326d1cbf9e4a43c061aadd9bc938c843a79e7b4fd2ad743",
    "0x395df67f0c2d2d9fe1ad08d1bc8b6627011959b79c53d7dd6a3536a33ab8a4fd",
    "0xe485d098507f54e7733a205420dfddbe58db035fa577fc294ebd14db90767a52",
    "0xa453611d9419d0e56f499079478fd72c37b251a94bfde4d19872c44cf65386e3",
    "0x829e924fdf021ba3dbbc4225edfece9aca04b929d6e75613329ca6f1d31c0bb4",
    "0xb0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773"
]
nonceList = [0]*9
RTDS = w3.eth.contract(abi=abi, bytecode=bytecode)
print(RTDS)

# Get the latest transaction
nonce = w3.eth.getTransactionCount(my_address)
print(nonce)

# Add security policy

# 1.  Build a transaction
transaction = RTDS.constructor().buildTransaction(
    {"chainId": chain_id, "gasPrice": w3.eth.gas_price, "from": my_address, "nonce": nonce})
# 2. Sign a transaction
signed_txn = w3.eth.account.sign_transaction( transaction, private_key=private_key)
# 3. Send a transaction
tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
contract_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

# Working with contracts
# 1. Contract addresses
# 2. Contract ABI
safe_wallet = w3.eth.contract(
    address=contract_receipt.contractAddress, abi=abi)


# Two ways of interact with the contracts
# 1. Call: Simulate making the call and getting a return value
# 2. Transact:  actually make a state change

successTransactionNumber = 0
unSuccessTransactionNumber = 0
overallGassFee = 0

"""
for i in range(4):
    transaction = safe_wallet.functions.addPolicy(i).buildTransaction(
        {"chainId": chain_id, "from": my_address, "gasPrice": w3.eth.gas_price, "nonce": nonce+1})
    nonce = nonce + 1
    signed_txn = w3.eth.account.sign_transaction(
        transaction, private_key=private_key)
    # Send this signed transaction
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(tx_receipt)
"""

# transact 100 Ether to the RTDS

transaction = safe_wallet.functions.deposit().buildTransaction( {"value": 10*(10**18), "chainId": chain_id, "from": my_address, "gasPrice": w3.eth.gas_price, "nonce": nonce+1})
nonce = nonce + 1
signed_txn = w3.eth.account.sign_transaction(
    transaction, private_key=private_key)
tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print("deposit to the safe wallet")
print(tx_receipt)


'''
# start test
for i in range(NUMBER_OF_TRANSACTIONS_BEFORE_COMPROMISE):
    # A random number between [0, 18]
    randomInt = random.randint(0, 17)
    # There is 1/2 chance of transfer in
    if randomInt < 9:
        transaction = safe_wallet.functions.deposit().buildTransaction({
            "from": other_addresses[randomInt],
            "chainId": chain_id,
            "gasPrice": w3.eth.gas_price,
            "nonce": nonceList[randomInt],
            "value": random.randint(1, 10*10**18)
        })
        signed_txn = w3.eth.account.sign_transaction(
            transaction, private_key=other_private_keys[randomInt])
        nonceList[randomInt] += 1
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    # There is 1/2 chance of transfer out
    else:
        transaction = safe_wallet.functions.transferOut(other_addresses[randomInt-9], random.randint(1, 10*10**18)).buildTransaction(
            {"chainId": chain_id, "from": my_address, "gasPrice": w3.eth.gas_price, "nonce": nonce+1, "gas": 300000})
        nonce = nonce + 1
        signed_txn = w3.eth.account.sign_transaction(transaction, private_key=private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        overallGassFee += int(tx_receipt["gasUsed"])
        print(tx_receipt)
'''
'''
for i in range(NUMBER_OF_TRANSACTIONS_BEFORE_COMPROMISE):
    randomInt = random.randint(0, 9)
    amount = random.randint(1, w3.eth.get_balance(
        contract_receipt.contractAddress))
    try:
        transaction = safe_wallet.functions.transferOut_maliciousTest(other_addresses[randomInt-9], amount).buildTransaction(
            {"chainId": chain_id, "from": my_address, "gasPrice": w3.eth.gas_price, "nonce": nonce+1, "gas": 300000})
        nonce = nonce + 1
        signed_txn = w3.eth.account.sign_transaction(
            transaction, private_key=private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        successTransactionNumber += amount
        overallGassFee += int(tx_receipt["gasUsed"])
    except:
        unSuccessTransactionNumber += amount

print("Success transaction number: ", successTransactionNumber)
print("unSuccess transaction number: ", unSuccessTransactionNumber)
print("gas used: ", overallGassFee)
'''