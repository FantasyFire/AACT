pragma solidity ^0.4.18;


import "./AACTAccessControl.sol";
import "./ERC20.sol";


/**
 * @title AACT token
 *
 * @dev https://github.com/ethereum/EIPs/issues/20
 */
contract AACT is ERC20, AACTAccessControl {

    string public constant name = "龙古多多";
    string public constant symbol = "AACT";
    uint256 public constant INITIAL_SUPPLY = 0;

    // 4 main accounts
    address public taxAccount;
    address public aipodAccount;
    address public livelihoodAccount;
    address public footstoneAccount;

    // events
    // emit when someone register successfully
    event Register(
        address _new, uint256 _newBalance,
        address _salesman, uint256 _salesmanBalance,
        address _taxAccount, uint256 _taxBalance,
        address _aipodAccount, uint256 _aipodBalance,
        address _livelihoodAccount, uint256 _livelihoodBalance,
        address _footstoneAccount, uint256 _footstoneBalance
    );

    mapping (address => mapping (address => uint256)) internal allowed;

    // @dev every company has a saleman
    mapping (address => address) salesmans;

    // @dev make sure msg.sender has been registered
    modifier registered() {
        require(salesmans[msg.sender] != address(0));
        _;
    }

    /// @notice Creates the main AACT smart contract instance.
    // @param _taxAccount the account of tax
    // @param _aipodAccount the account of AIPOD
    // @param _livelihoodAccount the account of livelihood
    // @param _footstoneAccount the account of footstone
    function AACT(
        address _taxAccount,
        address _aipodAccount,
        address _livelihoodAccount,
        address _footstoneAccount
    ) public {
        // Starts paused.
        paused = true;
        
        // the creator of the contract is also the initial CEO
        ceoAddress = msg.sender;

        // set 4 main accounts
        taxAccount = _taxAccount;
        aipodAccount = _aipodAccount;
        livelihoodAccount = _livelihoodAccount;
        footstoneAccount = _footstoneAccount;

        totalSupply_ = INITIAL_SUPPLY;
    }

    /**
    * @dev Register an company address with a salesman, only CEO has the privilege to invoke
    * @param _new the new address which need to be registered
    * @param _valuation the valuation of _new company
    * @param _salesman _new's salesman
    */
    function register(address _new, uint256 _valuation, address _salesman) public onlyCEO {
        // the _new must hasn't been registered
        require(salesmans[_new] == address(0));
        // set _salesman as _new's salesman
        salesmans[_new] = _salesman;
        // distribute AACTs
        // @notice the second param's type of distributeAACT is uint256, thus the decimal value will be cut
        distributeAACT(_new, 3 * _valuation / 10);
        distributeAACT(_salesman, 14 * _valuation / 100);
        distributeAACT(taxAccount, 14 * _valuation / 100);
        distributeAACT(aipodAccount, 14 * _valuation / 100);
        distributeAACT(livelihoodAccount, 14 * _valuation / 100);
        distributeAACT(footstoneAccount, 14 * _valuation / 100);
        // todo: emit Register event
        emit Register(_new, balances[_new], _salesman, balances[_salesman], taxAccount, balances[taxAccount], aipodAccount, balances[aipodAccount], livelihoodAccount, balances[livelihoodAccount], footstoneAccount, balances[footstoneAccount]);
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amount of tokens to be transferred
    */
    function transferFrom(address _from, address _to, uint256 _value) public before2020 returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    *
    * Beware that changing an allowance with this method brings the risk that someone may use both the old
    * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
    * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
    * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
    */
    function approve(address _spender, uint256 _value) public before2020 returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
    * @dev Function to check the amount of tokens that an owner allowed to a spender.
    * @param _owner address The address which owns the funds.
    * @param _spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
    */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
    * @dev Increase the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To increment
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _addedValue The amount of tokens to increase the allowance by.
    */
    function increaseApproval(address _spender, uint _addedValue) public before2020 returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
    * @dev Decrease the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To decrement
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _subtractedValue The amount of tokens to decrease the allowance by.
    */
    function decreaseApproval(address _spender, uint _subtractedValue) public before2020 returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

}
