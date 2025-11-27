// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LaunchToken
 * @notice Simple ERC20 token for BaseLauncher platform
 * @dev Tokens can only be minted once during initialization to prevent inflation
 */
contract LaunchToken {

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool private minted;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice Initialize the token with name, symbol, and mint initial supply
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _supply Total supply to mint (only happens once)
     * @param _recipient Address to receive the initial supply
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _recipient
    ) external {
        require(!minted, "Already minted");
        require(_recipient != address(0), "Invalid recipient");

        name = _name;
        symbol = _symbol;
        totalSupply = _supply;
        balanceOf[_recipient] = _supply;
        minted = true;

        emit Transfer(address(0), _recipient, _supply);
    }

    /**
     * @notice Transfer tokens to another address
     * @param _to Recipient address
     * @param _value Amount to transfer
     */
    function transfer(address _to, uint256 _value) external returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice Approve an address to spend tokens on your behalf
     * @param _spender Address authorized to spend
     * @param _value Amount approved
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another using allowance
     * @param _from Address to transfer from
     * @param _to Address to transfer to
     * @param _value Amount to transfer
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }
}
