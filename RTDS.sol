// SPDX-License-Identifier: MIT

// Smart contract that lets anyone deposit ETH into the contract
// Only the owner of the contract can withdraw the ETH
pragma solidity >=0.6.6 <0.9.0;
import "./Util.sol";


contract TFA {
    // A toy tFAAuthentication for testing
    function tFAAuthentication(uint256 token) public pure returns (bool) {
        if (token == 1) {
            return true;
        }
        return false;
    }

    function tFAAuthentication_test() public pure returns (bool) {
        return true;
    }
}

contract RTDS {
    // Owner of the smart contract
    address public owner;


    // A TFA contract
    TFA tFA = new TFA();


    constructor() {
        owner = msg.sender;
        latestAuthenticationBlockNumber= block.number;
    }

    /*
     *
     * Modifier
     */

    //modifier: https://medium.com/coinmonks/solidity-tutorial-all-about-modifiers-a86cf81c14cb
    modifier onlyOwner() {
        //is the message sender owner of the contract?
        require(msg.sender == owner);
        _;
    }

    modifier authenticated() {
        // is the operation under authenticated state?
        require(latestAuthenticationBlockNumber == block.number);
        _;
    }

    // may be accessed by child process
    uint256 internal latestAuthenticationBlockNumber;

    /*
     *
     * Foundation policy
     *
     */

    /*
     * Id: B0
     * Policy Name: Naive strict policy
     * Type: address independent policy
     * Transaction update: false
     * Deposite update: false
     * Description: release policies based on a user-defined white list of addresses
     * Data: whiteList:address[] O(k)
     *
     */

    function naiveStrictPolicy() internal pure returns (bool) {
        return false;
    }

    /*
     *  Release policies
     *
     */

    /*
     * Id: R0
     * Policy Name: white list release
     * Type: address dependent policy
     * Transaction update: false
     * Deposite update: false
     * Description: release policies based on a user-defined white list of addresses
     * Data: whiteList:address[] O(k)
     *
     */

    mapping(address => bool) whiteList;

    /*
     * Returns true if address is in the white list and false otherwise
     * @param address the address to check
     * @return true if address is in the white list and false otherwise
     */
    function whiteListReleasePolicy(Util.Account memory receiver)
        internal
        view
        returns (bool)
    {
        return whiteList[receiver.accountAddress];
    }

    function muteWhiteListReleasePolicy() internal pure returns (bool) {
        return false;
    }

    /*
     *
     */
    function addWhiteList(address receiver) public onlyOwner {
        whiteList[receiver] = true;
    }

    function removeWhiteList(address receiver) public onlyOwner {
        whiteList[receiver] = false;
    }

    /*
     * Global release policies
     *
     */

    /*
     * Id: GR0
     * Policy name: two factor authentication credit release policy.
     * Type: address independent policy
     * Privileges: Super user
     * Transaction update: false
     * Description: release if it's on authentication state and have enough credit
     * Data: (uint256) credit
     * Data: (uint256) creditValidTime
     *
     */

    uint256 private credit = 0;


    function tFAReleasePolicy(uint256 creditTaken)
        internal
        onlyOwner
        authenticated
        returns (bool)
    {
        if (creditTaken > credit) {
            return false;
        }
        credit = credit - creditTaken;
        return true;
    }


    /*
     *
     * Global mutation policies
     *
     */

    /*
     * Id: GM0
     * Policy name: maximum cumulative amount and ratio limit.
     * Type: address independent policy
     * Privileges: Other
     * Transaction update: true
     * Description: there is a cumulative limit on the amount and ratio of Wei to be released
     * Data: uint256 maximumAmount: maximum allowed amount of Wei to be released
     * Data: static uint256 maximumRatioFraction: maximum allowed amount of Wei to be released
     * Data: static uint256 maximumRatioMolecule: maximum allowed amount of Wei to be released
     * Data: uint256 cumulativeAmount
     * Data: uint256 baseAmount
     *
     */

    uint256 private maximumAllowedAmount = 1000;
    uint256 private maximumAllowedRatioMolecule = 10;
    uint256 private maximumAllowedRatioFraction = 1000;
    mapping(address =>uint256 ) private cumulativeAmountMap;
    uint256 private baseAmount;

    function maximumCumulativeAmountLimit(Util.Account storage sender, Util.Transaction memory proposalTransaction)
        internal
        view
        returns (bool)
    {
        require(
            maximumAllowedRatioMolecule <= maximumAllowedRatioFraction &&
                maximumAllowedRatioFraction != 0
        );
        // check whether there is overflow
        if (
            (maximumAllowedAmount > cumulativeAmountMap[sender.accountAddress] + proposalTransaction.amount) &&
            (baseAmount * maximumAllowedRatioMolecule >
                (cumulativeAmountMap[sender.accountAddress] + proposalTransaction.amount) * maximumAllowedRatioFraction)
        ) {
            // allowed amount. not need to mutate
            return false;
        }
        return true;
    }

    function updateMaximumCumulativeAmount(Util.Account storage sender, Util.Transaction memory transaction) internal {
        cumulativeAmountMap[sender.accountAddress] += transaction.amount;
    }

    function setMaximumAllowedAmount(uint256 newMaximumAllowedAmount)
        internal
        onlyOwner
        authenticated
    {
        maximumAllowedAmount = newMaximumAllowedAmount;
    }

    function getMaximumAllowedAmount() public view onlyOwner returns (uint256) {
        return maximumAllowedAmount;
    }

    function setMaximumAllowedRatio(
        uint256 newMaximumAllowedRatioMolecule,
        uint256 newMaximumAllowedRatioFraction
    ) internal onlyOwner authenticated {
        // this operation takes 2 credits
        require(credit >= 2);
        require(
            newMaximumAllowedRatioMolecule <= newMaximumAllowedRatioFraction
        );
        maximumAllowedRatioMolecule = newMaximumAllowedRatioMolecule;
        maximumAllowedRatioFraction = newMaximumAllowedRatioFraction;
        credit -= 2;
    }

    function getMaximumAllowedRatio()
        public
        view
        onlyOwner
        returns (uint256[2] memory)
    {
        uint256[2] memory ratio = [
            maximumAllowedRatioMolecule,
            maximumAllowedRatioFraction
        ];
        return ratio;
    }

    /*
     * Id: GM1
     * Policy name: maximum unauthentication interval policy.
     * Type: address independent policy
     * Privileges: other
     * Transaction update: false
     * Deposition update: false
     * Authentication update: true
     * Description: there is a interval limit, exceeds which a 2FA is required.
     * Data: (uint256) maximumUnauthencatedTime: maximum allowed time interval for unauthenticated state.
     * Data: (uint256) maximumDurationBlockNumber: maximum allowed block number interval for unauthenticated state.
     * Data: (uint256) latestAuthenticationBlockNumber
     *
     */

    // default maximum time duration is 1 days
    uint256 private maximumUnauthencatedTime = 24 * 60 * 60;
    // default maximum time duration is 128 blocks
    uint256 private maximumUnauthencatedBlockNumber = 128;



    function authenticatedStateDurationLimit(Util.Account memory account) internal view returns (bool) {
        if (
            account.latestVerifiedTime + maximumUnauthencatedTime <
            block.timestamp
        ) {

            return true;
        }

        if (
            account.latestVerifiedBlockNumber + maximumUnauthencatedBlockNumber <
            block.number
        ) {
            // mute
            return true;
        }
        return false;
    }

    function setMaximumUnauthencatedTime(uint256 newMaximumUnauthencatedTime)
        public
        onlyOwner
        authenticated
    {
        // this operation takes 2 credits
        require(
            credit >= 2,
            "setMaximumUnauthencatedTime: no enough credits. Authenticate first."
        );
        maximumUnauthencatedTime = newMaximumUnauthencatedTime;
        credit -= 2;
    }

    function getMaximumUnauthenticatedTime()
        public
        view
        onlyOwner
        returns (uint256)
    {

        return maximumUnauthencatedTime;
    }

    function setMaximumUnauthencatedBlockNumber(
        uint256 newMaximumUnauthencatedBlockNumber
    ) public onlyOwner authenticated {
        // this operation takes 2 credits
        require(
            credit >= 2,
            "setMaximumUnauthencatedTime: no enough credits. Authenticate first."
        );
        maximumUnauthencatedBlockNumber = newMaximumUnauthencatedBlockNumber;
        credit -= 2;
    }

    function getMaximumUnauthenticatedBlockNumber()
        public
        view
        onlyOwner
        returns (uint256)
    {
        return maximumUnauthencatedBlockNumber;
    }

    /*
     *  RTD
     *  Foundation policy: B0
     *  Release policy: R0
     *  Global mutation policy: GM0
     */
    function checkSecurity(Util.Account storage senderAccount , Util.Account memory receiverAccount, Util.Transaction memory proposalTransaction )
        internal
        view
        returns (bool)
    {
        // executes foundation policies
        bool foundationPoliciesResult = naiveStrictPolicy();

        // executes release policies
        bool releasePoliciesResult = false;
        if (releasePoliciesResult == false) {
            releasePoliciesResult =    releasePoliciesResult ||  (whiteListReleasePolicy(receiverAccount) && !muteWhiteListReleasePolicy());
        }

        // executes global mutation policies
        bool globalMutationPoliciesResult = false;
        if (globalMutationPoliciesResult == false) {
            globalMutationPoliciesResult = maximumCumulativeAmountLimit(senderAccount, proposalTransaction);
        }
        

        bool isSecure = foundationPoliciesResult ||
            ((!globalMutationPoliciesResult) && releasePoliciesResult);

        return isSecure;
    }

    /*
     *  transactionUpdator
     *  Foundation policy: B0
     *  Release policy: R0
     *  Global mutation policy: GM0
     */
    function transactionUpdator(Util.Account storage senderAccount , Util.Account memory receiverAccount, Util.Transaction memory proposalTransaction) internal {
        // updates release policies
        // no release policy should be updated after transaction

        // updates global mutation policy
        updateMaximumCumulativeAmount(senderAccount , proposalTransaction);
    }

    /*
     *  depositUpdator
     *  Foundation policy: B0
     *  Release policy: R0
     *  Global mutation policy: GM0
     */
    function depositUpdator(Util.Transaction memory transaction) internal {
        
    }


}
