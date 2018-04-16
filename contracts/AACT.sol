pragma solidity ^0.4.18;


import "./BasicToken.sol";
import "./ERC20.sol";


/**
 * @title AACT token
 *
 * @dev https://github.com/ethereum/EIPs/issues/20
 */
contract AACT is ERC20, BasicToken {

    string public constant name = "龙古多多";
    string public constant symbol = "AACT";
    uint256 public constant INITIAL_SUPPLY = 104000000000000;

    uint256 public totalFootstoneAACT;
    // structure for company
    struct Company {
        uint256 valuation;
        uint256 taxAACT;
        uint256 aipodAACT;
        uint256 livelihoodAACT;
        uint256 footstoneAACT;
        uint256 salesmanAACT;
    }

    mapping(address => Company) public companys;
    // 4 main pool
    address[] public footstoneAccounts;

    // events
    // emit when a company register successfully
    event CompanyRegister(
        uint256 taxAACT,
        uint256 aipodAACT,
        uint256 livelihoodAACT,
        uint256 footstoneAACT,
        uint256 salesmanAACT
    );
    // emit when a footstone member register successfully
    event FootstoneRegister(
        address _new
    );
    // emit when CEO withdraw someone's AACT
    event WithdrawAACT(
        address from,
        uint256 amount
    );

    mapping (address => mapping (address => uint256)) internal allowed;
    // @dev roles 5:super administrator, 4:footstoneMember, 3:company, 2:individual, 0:unregistered
    mapping (address => uint8) public roles;
    // @dev every company has a referee
    mapping (address => address) public referees;

    // @dev make sure msg.sender has registered
    modifier registered() {
        require(roles[msg.sender] > 0);
        _;
    }

    // @dev consider roles of company or higher than company as an administrator
    modifier isAdministrator() {
        require(roles[msg.sender] >= 3);
        _;
    }

    /// @notice Creates the main AACT smart contract instance.
    function AACT() public {
        // Starts paused.
        paused = true;
        
        // the creator of the contract is also the initial CEO
        ceoAddress = msg.sender;
        // CEO is the only one super administrator
        roles[ceoAddress] = 5;

        totalSupply_ = INITIAL_SUPPLY;
    }

    // the exchange rate will be adjust according to the totalSupply_
    // @notice the return value x, represents the exchange rate between AACT and rmb is 1 : x/1000000
    function getCurrentExchangeRate2rmb() public view returns(uint256) {
        return 1000000 + 99000000 * (INITIAL_SUPPLY - totalSupply_) / INITIAL_SUPPLY;
    }

    /// @dev Distribute _amount AACT to _to address
    function distributeAACT2address(address _to, uint256 _amount) internal {
        require(totalSupply_ >= _amount);
        balances[_to] = balances[_to].add(_amount);
        totalSupply_ = totalSupply_.sub(_amount);
    }

    /// @dev Distribute _amount AACT to _to a company
    function distributeAACT2company(address _to, uint256 _amount) internal {
        require(roles[_to] == 3);
        require(totalSupply_ >= _amount);
        // @notice the decimal value will be cut, thus the actual distributed AACT may be less than _amount
        uint256 _30percent = 3 * _amount / 10;
        uint256 _14percent = 14 * _amount / 100;
        balances[_to] = balances[_to].add(_30percent);
        Company storage comp = companys[_to];
        comp.valuation = _amount;
        comp.taxAACT = _14percent;
        comp.aipodAACT = _14percent;
        comp.livelihoodAACT = _14percent;
        comp.footstoneAACT = _14percent;
        comp.salesmanAACT = _14percent;
        totalSupply_ = totalSupply_.sub(_30percent + 5 * _14percent);
    }

    /**
    * @dev CEO has the privilege to withdraw someone's AACT
    */
    function withdrawAACT(address _from, uint256 _amount) public whenNotPaused onlyCEO {
        require(balances[_from] >= _amount);
        balances[_from] = balances[_from].sub(_amount);
        totalSupply_ = totalSupply_.add(_amount);
        emit WithdrawAACT(_from, _amount);
    }

    /**
    * @dev Register a footstone member address, only CEO has the privilege to invoke
    * @param _new the new footstone member
    */
    function registerFootstoneMember(address _new) public whenNotPaused onlyCEO {
        // @check does the _new need to be unregistered?
        // @check if need to recode CEO as the referee of _new?
        require(roles[_new] == 0);
        roles[_new] = 4;
        footstoneAccounts.push(_new);
        emit FootstoneRegister(_new);
    }
    /**
    * @dev Register a company address with a salesman, only administrator has the privilege to invoke
    * @param _new the new address which represents the company and need to be registered
    * @param _valuation the total valuation of _new company
    * @param _salesmen salesmen who offer assistance to _new company for register
    */
    function registerCompany(address _new, uint256 _valuation, address[] _salesmen) public whenNotPaused isAdministrator {
        // consider the message sender as the referee
        address _referee = msg.sender;
        // the _new must hasn't registered
        require(roles[_new] == 0);
        // the _referee's role privilege must be higher than company
        require(roles[_referee] >= 3);
        // create new Company
        roles[_new] = 3;
        // distribute AACTs
        distributeAACT2company(_new, _valuation);
        // set referee
        referees[_new] = _referee;
        Company storage comp = companys[_new];
        // transfer the footstone AACT to totalFootstoneAACT
        totalFootstoneAACT = totalFootstoneAACT.add(comp.footstoneAACT);
        comp.footstoneAACT = 0;
        // todo: transfer the salesman AACT to referee
        // first distribute the grandreferee part if the grandreferee exists
        address grandReferee = referees[_referee];
        if (grandReferee != address(0)) {
            uint256 grandRefereeRebate = comp.salesmanAACT.mul(4).div(14);
            balances[grandReferee] = balances[grandReferee].add(grandRefereeRebate);
            comp.salesmanAACT = comp.salesmanAACT.sub(grandRefereeRebate);
        }
        // and then, distribute the referee part
        uint256 len = _salesmen.length;
        uint256 refereeRebate = len == 0 ? comp.salesmanAACT : comp.salesmanAACT.mul(6).div(10);
        balances[_referee] = balances[_referee].add(refereeRebate);
        comp.salesmanAACT = comp.salesmanAACT.sub(refereeRebate);
        // at last, distribute the salesmen part
        if (len > 0) {
            uint256 perAACT = comp.salesmanAACT / len;
            uint256 totalSalesmenAACT = 0;
            for (uint256 i = 0; i < len; i++) {
                address salesmanAddress = _salesmen[i];
                if (roles[salesmanAddress] < 2) { // make sure salesman has registered
                    roles[salesmanAddress] = 2;
                }
                balances[_salesmen[i]] = balances[_salesmen[i]].add(perAACT);
                totalSalesmenAACT = totalSalesmenAACT.add(perAACT);
            }
            comp.salesmanAACT = comp.salesmanAACT.sub(totalSalesmenAACT);
        }
        // emit CompanyRegister event
        emit CompanyRegister(comp.taxAACT, comp.aipodAACT, comp.livelihoodAACT, comp.footstoneAACT, comp.salesmanAACT);
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amount of tokens to be transferred
    */
    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused after2020 returns (bool) {
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
    function approve(address _spender, uint256 _value) public whenNotPaused after2020 returns (bool) {
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
    function increaseApproval(address _spender, uint _addedValue) public whenNotPaused after2020 returns (bool) {
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
    function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused after2020 returns (bool) {
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
