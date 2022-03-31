Evaluate gas cost:  
https://medium.com/coinmonks/gas-cost-of-solidity-library-functions-dbe0cedd4678  

Sort in solidity:
https://medium.com/coinmonks/sorting-in-solidity-without-comparison-4eb47e04ff0d

function unique(<<type>> memory data, uint setSize) internal pure {
    uint length = data.length;
    bool[] memory set = new bool[](setSize);
    for (uint i = 0; i < length; i++) {
        set[data[i]] = true;
    }
    uint n = 0;
    for (uint i = 0; i < setSize; i++) {
        if (set[i]) {
            data[n] = i;
            if (++n >= length) break;
        }
    }
}