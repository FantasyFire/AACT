pragma solidity ^0.4.18;


import "./BasicToken.sol";
import "./ERC20.sol";


/**
 * @title AACT token
 *
 * @dev https://github.com/ethereum/EIPs/issues/20
 */
contract AACT is ERC20, BasicToken {

    string public constant name = "龙贝多多";
    string public constant symbol = "AACT";
    uint256 public constant TOTAL_SUPPLY = 104000000000000;
    uint8 public constant decimals = 18;

    uint256 totalSupply_;
    // withdraw AACT amount
    uint256 historySupply_;

    // all supply types
    uint8[] public supplyTypes;
    // total supply for each type
    mapping(uint8 => uint256) public supplys;

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

    address[] public footstoneAccounts;

    // events
    // when a company's worth upload successfully
    event CompanyWorthUpload(
        uint256 balanceAACT,
        uint256 taxAACT,
        uint256 aipodAACT,
        uint256 livelihoodAACT,
        uint256 footstoneAACT,
        uint256 salesmanAACT
    );

    // when someone gain AACT by helping a company upload its worth
    event GainRewardFromCompany(
        address rewardAddress,
        uint256 rewardAACT,
        address companyAddress
    );

    // when CEO withdraw someone's AACT
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
    modifier onlyAdmin() {
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

        // 1 for legal money assets
        supplyTypes.push(1);
        // 2 for resource assets
        supplyTypes.push(2);
        // total supply AACT amount
        totalSupply_ = 0;
    }

    /// @dev Allocate _amount AACT to _to a company
    function allocateAACT2company(address _to, uint256 _amount, uint8 _supplyType) internal {
        require(roles[_to] > 3);
        require(totalSupply_ + _amount < TOTAL_SUPPLY);
        // @notice the decimal value will be cut, thus the actual distributed AACT may be less than _amount
        uint256 _30percent = 3 * _amount / 10;
        uint256 _14percent = 14 * _amount / 100;
        balances[_to] = balances[_to].add(_30percent);
        Company storage comp = companys[_to];
        comp.valuation = comp.valuation.add(_amount);
        comp.taxAACT = comp.taxAACT.add(_14percent);
        comp.aipodAACT = comp.aipodAACT.add(_14percent);
        comp.livelihoodAACT = comp.livelihoodAACT.add(_14percent);
        comp.footstoneAACT = comp.footstoneAACT.add(_14percent);
        comp.salesmanAACT = comp.salesmanAACT.add(_14percent);
        uint256 _totalSupply = _30percent + 5 * _14percent;
        totalSupply_ = totalSupply_.add(_totalSupply);
        supplys[_supplyType] = supplys[_supplyType].add(_totalSupply);
    }

    /**
    * @dev CEO can transfer his AACT to anyone whenever
    */
    function transferAACT(address _to, uint256 _amount) public whenNotPaused onlyCEO {
        require(balances[ceoAddress] >= _amount);
        balances[ceoAddress] = balances[ceoAddress].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Transfer(ceoAddress, _to, _amount);
    }

    /**
    * @dev CEO has the privilege to withdraw someone's AACT
    */
    function withdrawAACT(address _from, uint256 _amount) public whenNotPaused onlyCEO {
        require(balances[_from] >= _amount);
        balances[_from] = balances[_from].sub(_amount);
        historySupply_ = historySupply_.add(_amount);
        emit WithdrawAACT(_from, _amount);
    }

    /**
    * @dev set role of an address, only CEO has the privilege to invoke
    * @param _new the new footstone member
    * @param _role the role will be set
    */
    function setRole(address _new, uint8 _role) public whenNotPaused onlyCEO {
        if (roles[_new] <= _role && _role < 5) {
            roles[_new] = _role;
            if (_role == 4) {
                footstoneAccounts.push(_new);
            }
        }
    }

    /**
    * @dev Upload a company's worth with some salesmen
    * @param _new the new address which represents the company and need to be registered
    * @param _referee the referee of _new company
    * @param _valuation the total valuation of _new company
    * @param _supplyType the supply type
    * @param _salesmen salesmen who offer assistance to _new company for register
    */
    function uploadCompanyWorth(address _new, address _referee, uint256 _valuation, uint8 _supplyType, address[] _salesmen) public whenNotPaused {
        // the _referee's role privilege must be higher than company
        require(roles[_referee] >= 3);
        // the _referee must be msg.sender or CEO
        require(ceoAddress == _referee || msg.sender == _referee);
        // elevate _new's role
        if (roles[_new] < 3) {
            roles[_new] = 3;
        }
        // distribute AACTs
        allocateAACT2company(_new, _valuation, _supplyType);
        // set referee if the company didn't has one
        if (referees[_new] == address(0)) {
            referees[_new] = _referee;
        }
        Company storage comp = companys[_new];
        // transfer the footstone AACT to CEO account
        balances[ceoAddress] = balances[ceoAddress].add(comp.footstoneAACT);
        comp.footstoneAACT = 0;
        // transfer the salesman AACT to referee
        // first distribute the grandreferee part if the grandreferee exists
        address grandReferee = referees[_referee];
        if (grandReferee != address(0)) {
            uint256 grandRefereeRebate = comp.salesmanAACT.mul(4).div(14);
            balances[grandReferee] = balances[grandReferee].add(grandRefereeRebate);
            comp.salesmanAACT = comp.salesmanAACT.sub(grandRefereeRebate);
            emit GainRewardFromCompany(grandReferee, grandRefereeRebate, _new);
        }
        // and then, distribute the referee part
        uint256 len = _salesmen.length;
        uint256 refereeRebate = len == 0 ? comp.salesmanAACT : comp.salesmanAACT.mul(6).div(10);
        balances[_referee] = balances[_referee].add(refereeRebate);
        comp.salesmanAACT = comp.salesmanAACT.sub(refereeRebate);
        emit GainRewardFromCompany(_referee, refereeRebate, _new);
        // at last, distribute the salesmen part
        if (len > 0) {
            allocateSalemenAACT(_new, len, _salesmen);
        }
        // CompanyWorthUpload event
        emit CompanyWorthUpload(balances[_new], comp.taxAACT, comp.aipodAACT, comp.livelihoodAACT, comp.footstoneAACT, comp.salesmanAACT);
    }
    
    /**
    * @dev calculate totalSupply by count supplys of each type
    */
    function allocateSalemenAACT(address _new, uint256 len, address[] _salesmen) internal {
        Company storage comp = companys[_new];
        uint256 perAACT = comp.salesmanAACT / len;
        uint256 totalSalesmenAACT = 0;
        for (uint8 i = 0; i < len; i++) {
            address salesmanAddress = _salesmen[i];
            if (roles[salesmanAddress] < 2) { // make sure salesman has registered
                roles[salesmanAddress] = 2;
            }
            balances[_salesmen[i]] = balances[_salesmen[i]].add(perAACT);
            totalSalesmenAACT = totalSalesmenAACT.add(perAACT);
            emit GainRewardFromCompany(_salesmen[i], perAACT, _new);
        }
        comp.salesmanAACT = comp.salesmanAACT.sub(totalSalesmenAACT);
    }

    /**
    * @dev return totalSupply_
    */
    function totalSupply() public view returns(uint256) {
        return totalSupply_;
    }

    /**
    * @dev return historySupply_
    */
    function historySupply() public view returns(uint256) {
        return historySupply_;
    }

    /**
    * @dev Add a new supply type
    */
    function addSupplyType(uint8 _newType) public onlyCEO {
        bool typeExist = false;
        for (uint8 i = 0; i < supplyTypes.length; i++) {
            if (supplyTypes[i] == _newType) {
                typeExist = true;
                break;
            }
        }
        if (!typeExist) {
            supplyTypes.push(_newType);
        }
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
