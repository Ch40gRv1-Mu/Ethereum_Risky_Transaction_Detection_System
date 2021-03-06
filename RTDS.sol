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
     * Policy name: Small amount release.
     *
     */

    mapping(address=>uint256) smallAmountMap;
    mapping(address=>uint256[]) smallRatioMap;
    
    uint256 DEFAULT_SMALL_AMOUNT = 1000000000;
    // 1 ether
    uint256 SMALL_AMOUNT_UPPERBOUND = 1000000000000000000;
    uint256[] DEFAULT_SMALL_RATIO = [1,10000];
    uint256[] SMALL_RATIO_UPPERBOUND = [1,10];

    function getSmallAmount(address senderAccountAddress) public view returns (uint256){
        return smallAmountMap[senderAccountAddress]; 
    }

    function getSmallRatio(address senderAccountAddress) public view returns (uint256[] memory) {
        uint256[] memory result =  smallRatioMap[senderAccountAddress];
        return result;
    }
    
    function setSmallAmount (address senderAccountAddress, uint256 newAmount) public {
          require(newAmount<SMALL_AMOUNT_UPPERBOUND, "New small amount reaches the allowed upperbound (1 eth)");
          // The account should be registered
          smallAmountMap[senderAccountAddress] = newAmount;
    }

    function setSmallRatio(address senderAccountAddress, uint256[] memory newRatio) public {
        require(newRatio.length == 2, 'The new ratio should follow format [<numerator>, <denominator>]');
        require(newRatio[0]<=newRatio[1], "The new ratio should between 0 and 1");
        require (newRatio[0]* SMALL_RATIO_UPPERBOUND[1] < SMALL_RATIO_UPPERBOUND[0]*newRatio[1], "New small ratio reaches the allowed upperbound (1/10)");
        // The account should be registered
        smallRatioMap[senderAccountAddress] = newRatio;
    }

    function smallAmountRelease(Util.Account memory senderAccount, uint256 amount) public view returns (bool) {
        if (amount < smallAmountMap[senderAccount.accountAddress]) {
            return true;
        }

        if (amount * smallRatioMap[senderAccount.accountAddress][1]<senderAccount.balance * smallRatioMap[senderAccount.accountAddress][0]) {
            return true;
        }

        return false;

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

    // 10 ethers
    uint256 private DEFAULT_MAXIMUM_ALLOWED_AMOUNT = 10000000000000000000;
    uint256[] private  DEFAULT_MAXIMUM_ALLOWED_RATIO = [1, 1000];
    // Each block takes less than 20 s average
    // 3*60*24 defaultly less than 1 day
    uint256 private DEFAULT_UNAUTHENTICATED_INTERVAL = 360 ;
    // Upper bound 10 ether
    uint256 private MAXIMUM_AMOUNT_TO_UNREGISTERED_ACCOUNT_UPPER_BOUND = 10000000000000000000;
    // 1 milliether
    uint256 private DEFAULT_MAXIMUM_AMOUNT_TO_UNREGISTERED_ACCOUNT = 1000000000000000;
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
     */


    mapping(address => uint256 ) private maximumUnauthencatedBlockNumberMap;

    // temporarily put as public for testing purpose
    function maximumUnauthenticatedIntervalLimit(Util.Account memory account) public view returns (bool) {

        if (
            account.latestVerifiedBlockNumber + maximumUnauthencatedBlockNumberMap[account.accountAddress] <
            block.number
        ) {
            // mute
            return true;
        }
        return false;
    }

    function setMaximumUnauthenticatedBlockNumber(address accountAddress,
        uint256 newMaximumUnauthencatedBlockNumber
    ) public onlyOwner {
        maximumUnauthencatedBlockNumberMap[accountAddress] = newMaximumUnauthencatedBlockNumber;
    }

    function getMaximumUnauthenticatedBlockNumber(address accountAddress) 
        public
        view
        onlyOwner
        returns (uint256)
    {
        return maximumUnauthencatedBlockNumberMap[accountAddress];
    }


    /*
     * Id: GM2
     * Policy name: maximumAmountToUnregisteredAccount.
     * @param {address} senderAddress The address of the owner of the sender account to
     * @param isregistered Is the receiver account registered
     * @param amount The amount of Wei of the proposed transaction
     */


    mapping(address=> uint256) maximumAmountToUnregisteredAccountMap;

    // temporarily set as public for testing purposes
    function maximumAmountToUnregisteredAccountLimit(address sendeAccountAddress, bool isRegistered, uint256 amount) public view returns(bool) {
        if (isRegistered) {
            // not mute
            return false;
        } else if (amount< maximumAmountToUnregisteredAccountMap[sendeAccountAddress]) {
            return false;
        } else {
            return true;
        } 
    }


    function setMaximumAmountToUnregisteredAccount(address accountAddress, uint256 newMaximumAllowedAmountToUnregisteredAccount) onlyOwner public {
        require(newMaximumAllowedAmountToUnregisteredAccount<MAXIMUM_AMOUNT_TO_UNREGISTERED_ACCOUNT_UPPER_BOUND);
        maximumAmountToUnregisteredAccountMap[accountAddress] = newMaximumAllowedAmountToUnregisteredAccount;
    }

    function getMaximumAmountToUnregisteredAccount(address accountAddress) onlyOwner public view returns(uint256) {
        return maximumAmountToUnregisteredAccountMap[accountAddress];
    }

    /**
    * GM3: Maximum frequency limit 
    *
    *
    */

    // One thousand blocks take around 4 hours
    uint256 INTERVAL_OF_FREQUENCY = 1000;
    // Upperbound is around 10 transactions per 4 hours
    uint256 MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND = 10;
    uint256 DEFAULT_MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION = 5;

    mapping(address=> uint256) maximumAllowedTransactionsPerThousandBlocks;
    mapping(address=> Util.Queue) recentTransactions;


    // set to public for test purposes
    /**
    *  maximumFrequencyLimit
    *  @param {address} senderAccountAddress The ethereum address that owns certain account
    *  @return {bool} True if it should be muted, False otherwise
    */ 
    function maximumFrequencyLimit(address senderAccountAddress) public view returns (bool){
        //popOutdatedTransactions(senderAccountAddress);
        // exclusive bound: in case the account is not registered and no transactions in the sender account
        bool shouldMute = getRecentTransactionsNumber(senderAccountAddress) >= maximumAllowedTransactionsPerThousandBlocks[senderAccountAddress];
        return shouldMute;
    }


    // public for testing purposes
    function popOutdatedTransactions(address senderAccountAddress) public {
            while (
            recentTransactions[senderAccountAddress].front != recentTransactions[senderAccountAddress].back
            &&
            recentTransactions[senderAccountAddress].data[recentTransactions[senderAccountAddress].front] 
            + INTERVAL_OF_FREQUENCY < block.number
            ) {
            // will at most cache 10 datas per account
            popTransaction(senderAccountAddress); 
        }
    }

    // public for test purpose
    function getRecentTransactionsNumber(address senderAccountAddress) public view returns(uint256) {
        
        return (recentTransactions[senderAccountAddress].back+MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND-recentTransactions[senderAccountAddress].front) % MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND;
    }

    // public for test purpose
    function popTransaction(address senderAccountAddress) public {
        delete recentTransactions[senderAccountAddress].data[recentTransactions[senderAccountAddress].front];
        recentTransactions[senderAccountAddress].front = (recentTransactions[senderAccountAddress].front + 1) % MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND;
    }


    function getMaximumAllowedTransactionsPerThousandBlocks(address senderAccountAddress) public view returns (uint256) {
        return maximumAllowedTransactionsPerThousandBlocks[senderAccountAddress];
    }

    function setMaximumAllowedTransactionsPerThousandBlocks(address senderAccountAddress, uint256 newMAximumAllowedTransactionsPerThousandBlocks) public {
    
        require(newMAximumAllowedTransactionsPerThousandBlocks <= MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND, "The new value exceed the upperbound for maximum allowed transactions per thousand blocks.");
        maximumAllowedTransactionsPerThousandBlocks[senderAccountAddress] = newMAximumAllowedTransactionsPerThousandBlocks;
    }

    // set to public for test purposes
    function updateRecentTransactions(address senderAccountAddress) public {
    
        // strict upperbound
        if (getRecentTransactionsNumber(senderAccountAddress) == MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND-1) {
            popTransaction(senderAccountAddress);
        }


        recentTransactions[senderAccountAddress].back = (recentTransactions[senderAccountAddress].back+1) % MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION_UPPERBOUND;
        recentTransactions[senderAccountAddress].data[recentTransactions[senderAccountAddress].back] = block.number;
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


    function preSecurityCheckUpdator(Util.Account memory senderAccount , Util.Account memory receiverAccount, Util.Transaction memory proposedTransaction) public{
        popOutdatedTransactions(senderAccount.accountAddress);
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
        updateRecentTransactions(senderAccount.accountAddress);

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
        maximumAmountToUnregisteredAccountMap[newAccount.accountAddress] = DEFAULT_MAXIMUM_AMOUNT_TO_UNREGISTERED_ACCOUNT;  
        baseBalanceMap[newAccount.accountAddress] = newAccount.balance;
        maximumUnauthencatedBlockNumberMap[newAccount.accountAddress] = DEFAULT_UNAUTHENTICATED_INTERVAL;
        maximumAllowedTransactionsPerThousandBlocks[newAccount.accountAddress] = DEFAULT_MAXIMUM_AMOUNT_PER_THOUSAND_TRANSACTION;

        smallAmountMap[newAccount.accountAddress] = DEFAULT_SMALL_AMOUNT;
        smallRatioMap[newAccount.accountAddress] = DEFAULT_SMALL_RATIO;
    }


}
