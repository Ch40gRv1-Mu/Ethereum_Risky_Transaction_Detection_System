// SPDX-License-Identifier: MIT

// Smart contract that lets anyone deposit ETH into the contract
// Only the owner of the contract can withdraw the ETH
pragma solidity >=0.6.6 <0.9.0;
import "./Util.sol";


contract RTDS {
    // Owner of the smart contract
    address public owner;




    constructor() {
        owner = msg.sender;
       //latestAuthenticationBlockNumber= block.number;
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
     * Policy name: maximum cumulative amount limit.
     */

    uint256 private DEFAULT_MAXIMUM_ALLOWED_AMOUNT = 1000;
    uint256[] private  DEFAULT_MAXIMUM_ALLOWED_RATIO = [10, 1000];
    mapping(address =>uint256 ) private cumulativeUnauthenticatedAmountMap;
    mapping(address =>uint256 ) private baseBalanceMap;
    mapping(address =>uint256 ) private maximumAllowedAmountMap;
    mapping(address =>uint256[]) private maximumAllowedRatioMap;
    

    
    // temporarily be public for testing purposes.
    function maximumCumulativeAmountLimit(address senderAccountAddress, uint256 proposedAmount)
        public
        view
        returns (bool)
    {
        // maximumAllowedRatio Molecule: maximumAllowedRatioMap[sender.accountAddress][0]
        // maximumAllowedRatio Fraction: maximumAllowedRatioMap[sender.accountAddress][1]
        require(
            maximumAllowedRatioMap[senderAccountAddress][0] <= maximumAllowedRatioMap[senderAccountAddress][1] &&
                maximumAllowedRatioMap[senderAccountAddress][1] != 0
        );

        // check whether there is overflow
        //(baseBalanceMap[senderAccountAddress] * maximumAllowedRatioMap[senderAccountAddress][0] >         (cumulativeUnauthenticatedAmountMap[senderAccountAddress] + proposedAmount) * maximumAllowedRatioMap[senderAccountAddress][1])
        if (
            (maximumAllowedAmountMap[senderAccountAddress] > cumulativeUnauthenticatedAmountMap[senderAccountAddress] + proposedAmount) && (baseBalanceMap[senderAccountAddress] * maximumAllowedRatioMap[senderAccountAddress][0] > (cumulativeUnauthenticatedAmountMap[senderAccountAddress] + proposedAmount) * maximumAllowedRatioMap[senderAccountAddress][1]))
             {
            // allowed amount not need to mutate
            return false;
        }
        return true;
    }

    function updateMaximumCumulativeAmount(address senderAccountAddress, uint256 amount) internal {
        cumulativeUnauthenticatedAmountMap[senderAccountAddress] += amount;
    }

    function getMaximumCumulativeAmount(address senderAccountAddress) public view onlyOwner returns(uint256) {
        return  cumulativeUnauthenticatedAmountMap[senderAccountAddress];
    }



    function setMaximumAllowedAmount(uint256 newMaximumAllowedAmount, address senderAccountAddress)
        public
        onlyOwner
    {
        maximumAllowedAmountMap[senderAccountAddress] = newMaximumAllowedAmount;
    }



    function getMaximumAllowedAmount(address senderAccountAddress) public view onlyOwner returns (uint256) {
        return maximumAllowedAmountMap[senderAccountAddress];
    }

    function setMaximumAllowedRatio(
        uint256 [] memory newMaximumAllowedRatio, address senderAccountAddress
    ) internal onlyOwner{
        require(newMaximumAllowedRatio.length == 2
        && newMaximumAllowedRatio[0]<=newMaximumAllowedRatio[1] && newMaximumAllowedRatio[1]==1);
        maximumAllowedRatioMap[senderAccountAddress] = newMaximumAllowedRatio;
    }

    function getMaximumAllowedRatio(address senderAccountAddress)
        public
        view
        onlyOwner
        returns (uint256[] memory)
    {
        uint256[] memory ratio = maximumAllowedRatioMap[senderAccountAddress];
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



    // temporarily put as public for testing purpose
    function maximumUnauthenticatedIntervalLimit(Util.Account memory account) public view returns (bool) {
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

    function setMaximumUnauthenticatedTime(uint256 newMaximumUnauthencatedTime)
        public
        onlyOwner
    {
        maximumUnauthencatedTime = newMaximumUnauthencatedTime;
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
    ) public onlyOwner {
        maximumUnauthencatedBlockNumber = newMaximumUnauthencatedBlockNumber;
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
    function checkSecurity(Util.Account memory senderAccount , Util.Account memory receiverAccount, Util.Transaction memory proposedTransaction )
        public
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
            globalMutationPoliciesResult = maximumCumulativeAmountLimit(senderAccount.accountAddress, proposedTransaction.amount);
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
    function transactionUpdator(Util.Account memory senderAccount , Util.Account memory receiverAccount, Util.Transaction memory proposedTransaction) public {
        // updates release policies
        // no release policy should be updated after transaction

        // updates global mutation policy
        updateMaximumCumulativeAmount(senderAccount.accountAddress , proposedTransaction.amount);
    }


        /*
     *  depositUpdator
     *  Foundation policy: B0
     *  Release policy: R0
     *  Global mutation policy: GM0
     */
    function depositUpdator(Util.Account memory receiverAccount, Util.Transaction memory transaction) internal {
        require(receiverAccount.isRegistered==true, "Falled to update deposit record, the user is not registered yet.");   
    }

    function registrationUpdator(Util.Account memory newAccount) public onlyOwner {
        // update for GM0
        require(cumulativeUnauthenticatedAmountMap[newAccount.accountAddress]==0);
        maximumAllowedAmountMap[newAccount.accountAddress] = DEFAULT_MAXIMUM_ALLOWED_AMOUNT;
        maximumAllowedRatioMap[newAccount.accountAddress] = DEFAULT_MAXIMUM_ALLOWED_RATIO;
        baseBalanceMap[newAccount.accountAddress] = newAccount.currentBalance;
    }


}
