pragma solidity >=0.6.6 <0.9.0;

import "./ECC.sol";
import "./Util.sol";
import "./RTDS.sol";

contract Bank {
    bytes32 _identity;
    address _owner;
    ChainType _deployedChainType;
    uint256 _randNonce;
    RTDS riskTransactionDetector;

    enum ChainType {
        Sim,
        Test,
        Main
    }
    enum RequestType {
        Registration,
        Authentication
    }
    enum SigningAlgorithm {
        Secp256k1WithKeccak256,
        Secp256r1WithSHA256
    }

    event NewRegistrationChallenge(address account, bytes32 challenge);
    event NewRegistrationStatus(address account, bool isRegistrated);

    event NewTransactionsChallenge(address account, bytes32 challenge);
    event NewTransactionStatus(address to, uint256 amount, bool isRegistrated);

    mapping(address => Util.Account) _addressMap;

    constructor(ChainType chainType) public {
        _randNonce = 0;
        _owner = msg.sender;
        _deployedChainType = chainType;
        _identity = "tttttttttttttttttttttttttttttttt";
    }

    // getRegistrationChallenge generates a challenge for the U2F Client to construct a RegistrationRequest object
    function getRegistrationChallenge() public payable {
        require(
            _addressMap[msg.sender].isRegistered == false,
            "Only unregistrated accounts can request registration."
        );

        // first create the random part of the challenge
        bytes32 randomChallenge = getRandom();

        // then create the hash that a valid response should have
        _addressMap[msg.sender].registrationChallenge = sha256(
            abi.encodePacked(
                RequestType.Registration,
                msg.sender,
                randomChallenge,
                _identity
            )
        );

        emit NewRegistrationChallenge(
            msg.sender,
            _addressMap[msg.sender].registrationChallenge
        );
    }

    // answerRegistrationChallenge checks if a) the challenge was the correct one and b) signature matches the supplied attestation key
    function answerRegistrationChallenge(
        bytes32 applicationParameter,
        bytes memory clientData,
        bytes memory keyHandle,
        bytes memory userPublicKey,
        bytes memory attestationKey,
        bytes memory signature,
        SigningAlgorithm signingAlgorithm
    ) public {
        require(
            _addressMap[msg.sender].isRegistered == false,
            "the account answered registion challenges already"
        );
        require(
            Util.verifyCorrectChallenge(
                clientData,
                _addressMap[msg.sender].registrationChallenge
            ),
            "Wrong challenge in ClientData"
        );

        // check if the application identity matches
        require(
            sha256(abi.encodePacked(_identity)) == applicationParameter,
            "Application identity does not match."
        );

        bytes32 challengeParameter = sha256(clientData);

        // construct the message which the U2F Token/Client should have signed correctly
        bytes memory message = new bytes(
            1 +
                applicationParameter.length +
                challengeParameter.length +
                keyHandle.length +
                userPublicKey.length
        );

        // first part of the message is reserved and not used yet
        message[0] = "";

        // add data to message object
        uint256 messageIndex = 1;

        for (uint256 i = 0; i < applicationParameter.length; i++) {
            message[messageIndex++] = applicationParameter[i];
        }
        for (uint256 i = 0; i < challengeParameter.length; i++) {
            message[messageIndex++] = challengeParameter[i];
        }
        for (uint256 i = 0; i < keyHandle.length; i++) {
            message[messageIndex++] = keyHandle[i];
        }
        for (uint256 i = 0; i < userPublicKey.length; i++) {
            message[messageIndex++] = userPublicKey[i];
        }

        bool goodSignature = false;

        // check the signature with the specified algorithm
        if (signingAlgorithm == SigningAlgorithm.Secp256k1WithKeccak256) {
            goodSignature = ECC.verifyECRecover(
                keccak256(message),
                attestationKey,
                signature
            );
        } else if (signingAlgorithm == SigningAlgorithm.Secp256r1WithSHA256) {
            goodSignature = ECC.verifySECP256R1(
                sha256(message),
                attestationKey,
                signature
            );
        }

        if (goodSignature) {
            _addressMap[msg.sender].isRegistered = true;
            _addressMap[msg.sender].registeredPublicKey = userPublicKey;
            _addressMap[msg.sender].keyHandle = keyHandle;
        }

        emit NewRegistrationStatus(msg.sender, goodSignature);
    }

    function transferFunds(address to, uint256 amount) public payable {
        // XXX: check balance here
        //require(_addressMap[msg.sender].balance >= amount, "Not enough funds!");
        //_addressMap[msg.sender].balance -= amount;

        bytes32 randomChallenge = getRandom();

        Util.Transaction memory newTransaction;
        newTransaction.amount = amount;
        newTransaction.receiverAddress = to;
        newTransaction.senderAddress = msg.sender;
        newTransaction.transactionTime = 0;
        newTransaction.transactionChallenge = sha256(
            abi.encodePacked(
                newTransaction.receiverAddress,
                newTransaction.amount,
                newTransaction.transactionTime,
                RequestType.Registration,
                randomChallenge,
                _identity
            )
        );

        bool hasBeenInserted = false;

        for (
            uint256 i = 0;
            i < _addressMap[msg.sender]._delayedTransactions.length;
            i++
        ) {
            if (
                _addressMap[msg.sender]._delayedTransactions[i].isRegistrated == true
            ) {
                _addressMap[msg.sender]._delayedTransactions[
                    i
                ] = newTransaction;
                hasBeenInserted = true;
            }
        }

        if (!hasBeenInserted)
            _addressMap[msg.sender]._delayedTransactions.push(newTransaction);

        // then create the hash that a valid response should have
        emit NewTransactionsChallenge(
            msg.sender,
            newTransaction.transactionChallenge
        );
    }

    function verifyTransaction(
        bytes32 applicationParameter,
        bytes1 userPresence,
        bytes4 counter,
        bytes memory clientData,
        bytes memory signature,
        bytes32 transactionChallenge,
        SigningAlgorithm signingAlgorithm
    ) public payable {
        require(
            _addressMap[msg.sender].isRegistered == true,
            "Only registered accounts can respond to transaction challenges"
        );

        // check if the application identity matches
        require(
            sha256(abi.encodePacked(_identity)) == applicationParameter,
            "Application identity does not match."
        );

        bytes32 challengeParameter = sha256(clientData);

        // construct the message which the U2F Token/Client should have signed correctly
        bytes memory message = new bytes(
            applicationParameter.length +
                userPresence.length +
                counter.length +
                challengeParameter.length
        );

        // add data to message object
        uint256 messageIndex = 0;

        for (uint256 l = 0; l < applicationParameter.length; l++) {
            message[messageIndex++] = applicationParameter[l];
        }
        for (uint256 l = 0; l < userPresence.length; l++) {
            message[messageIndex++] = userPresence[l];
        }
        for (uint256 l = 0; l < counter.length; l++) {
            message[messageIndex++] = counter[l];
        }
        for (uint256 l = 0; l < challengeParameter.length; l++) {
            message[messageIndex++] = challengeParameter[l];
        }

        bool goodSignature = false;

        // check the signature with the specified algorithm
        if (signingAlgorithm == SigningAlgorithm.Secp256k1WithKeccak256) {
            goodSignature = ECC.verifyECRecover(
                keccak256(message),
                _addressMap[msg.sender].registeredPublicKey,
                signature
            );
        } else if (signingAlgorithm == SigningAlgorithm.Secp256r1WithSHA256) {
            goodSignature = ECC.verifySECP256R1(
                sha256(message),
                _addressMap[msg.sender].registeredPublicKey,
                signature
            );
        }
        uint256 i = 0;

        if (goodSignature) {
            for (
                i = 0;
                i < _addressMap[msg.sender]._delayedTransactions.length;
                i++
            ) {
                if (
                    _addressMap[msg.sender]
                        ._delayedTransactions[i]
                        .transactionChallenge == transactionChallenge
                ) {
                    require(
                        Util.verifyCorrectChallenge(
                            clientData,
                            transactionChallenge
                        ),
                        "Wrong challenge in ClientData"
                    );

                    _addressMap[msg.sender]
                        ._delayedTransactions[i]
                        .isRegistrated = true;
                    emit NewTransactionStatus(
                        _addressMap[msg.sender]
                            ._delayedTransactions[i]
                            .receiverAddress,
                        _addressMap[msg.sender]._delayedTransactions[i].amount,
                        true
                    );

                    return;
                }
            }
        }

        emit NewTransactionStatus(
            _addressMap[msg.sender]._delayedTransactions[i].receiverAddress,
            _addressMap[msg.sender]._delayedTransactions[i].amount,
            false
        );
    }

    function getDelayedTransactions()
        public
        view
        returns (Util.Transaction[] memory)
    {
        return _addressMap[msg.sender]._delayedTransactions;
    }

    function getBalance() public view returns (uint256 balance) {
        return _addressMap[msg.sender].balance;
    }

    function deposit() public payable {
        require(
            _addressMap[msg.sender].isRegistered == true,
            "Please register first before deposit in"
        );
        _addressMap[msg.sender].balance += msg.value;
    }

    function getRandom() private returns (bytes32 random) {
        _randNonce++;
        return
            bytes32(
                keccak256(
                    abi.encodePacked(
                        this,
                        msg.sender,
                        blockhash(block.number - 1),
                        block.number - 1,
                        block.coinbase,
                        block.difficulty,
                        _randNonce
                    )
                )
            );
    }

    function getKeyHandle() public view returns (bytes memory handle) {
        return _addressMap[msg.sender].keyHandle;
    }

    function getIdentity() public view returns (bytes32 identity) {
        return _identity;
    }
}
