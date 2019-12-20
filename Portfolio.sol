pragma solidity >=0.5.0 <0.6.0;

library SafeMathAddSub {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
}

/**
* {IERC20} interface.
*/
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Portfolio {
    using SafeMathAddSub for uint256;

    /**
    * balance - total tokens that not in portfel
    */
    mapping(address => mapping(address => uint256)) balance;
    mapping(address => mapping(address => uint256)) existing_tokens;
    mapping(address => address[]) tokens_collection;

    /**
    * Portfel is portfolio.
    * User can have not only one portfel.
    */
    struct Portfel {
        string name;
        address[] adresses;
        uint256[] amounts;
    }

    /**
    * portfels - array of portfels of user.
    */
    mapping(address => Portfel[]) portfels;

    function createPortfel(string calldata name, address[] calldata _token_addreses, uint256[] calldata amounts) external returns(bool success) {
        require(_token_addreses.length == amounts.length);
        for (uint256 i = 0; i < _token_addreses.length; i++) {
            if (balance[msg.sender][_token_addreses[i]] < amounts[i]) {
                return false;
            }
        }
        for (uint256 i = 0; i < _token_addreses.length; i++) {
            balance[msg.sender][_token_addreses[i]] = balance[msg.sender][_token_addreses[i]].sub(amounts[i]);
            if (balance[msg.sender][_token_addreses[i]] == 0) {
                delete tokens_collection[msg.sender][existing_tokens[msg.sender][_token_addreses[i]]];
                existing_tokens[msg.sender][_token_addreses[i]] = 0;
            }
        }
        portfels[msg.sender].push(Portfel(name, _token_addreses, amounts));
        return true;
    }

    function getPortfel(uint256 portfel_id) external view returns(string memory name, address[] memory adresses, uint256[] memory amounts) {
        return(portfels[msg.sender][portfel_id].name, portfels[msg.sender][portfel_id].adresses, portfels[msg.sender][portfel_id].amounts);
    }

    function getPortfolioSize() external view returns(uint256 number_portefls_in_portfolio) {
        return(portfels[msg.sender].length);
    }


    function fetchFromPortfel(uint256 _portfelId, address _token_address, uint256 _amount) external returns(bool success) {
        require(portfels[msg.sender][_portfelId].adresses.length > 0);
        uint256 _token_address_index = 0;
        for (uint256 i = 0; i < portfels[msg.sender][_portfelId].adresses.length; i++) {
            if (portfels[msg.sender][_portfelId].adresses[i] == _token_address) {
                _token_address_index = i;
                break;
            }
        }
        require(_token_address_index >= 0);
        require(portfels[msg.sender][_portfelId].adresses[_token_address_index] == _token_address);
        require(portfels[msg.sender][_portfelId].amounts[_token_address_index] >= _amount);

        portfels[msg.sender][_portfelId].amounts[_token_address_index] = portfels[msg.sender][_portfelId].amounts[_token_address_index].sub(_amount);
        balance[msg.sender][_token_address] = balance[msg.sender][_token_address].add(_amount);

        if (tokens_collection[msg.sender].length == 0 || existing_tokens[msg.sender][_token_address] == 0 && tokens_collection[msg.sender][0] != _token_address) {
            uint id = tokens_collection[msg.sender].push(_token_address);
            existing_tokens[msg.sender][_token_address] = id;
        }

        return true;
    }

    function deletePortfel(uint256 _portfelId) external returns(bool success) {
        require(portfels[msg.sender][_portfelId].adresses.length > 0);
        for (uint256 i = 0; i < portfels[msg.sender][_portfelId].adresses.length; i++) {
            uint256 amount = portfels[msg.sender][_portfelId].amounts[i];
            address _token_address = portfels[msg.sender][_portfelId].adresses[i];
            // portfels[msg.sender][_portfelId].amounts[i] = portfels[msg.sender][_portfelId].amounts[i].sub(amount);
            balance[msg.sender][_token_address] = balance[msg.sender][_token_address].add(amount);
            delete portfels[msg.sender][_portfelId].amounts[i];
            delete portfels[msg.sender][_portfelId].adresses[i];
            
            if (tokens_collection[msg.sender].length == 0 || existing_tokens[msg.sender][_token_address] == 0 && tokens_collection[msg.sender][0] != _token_address) {
                uint id = tokens_collection[msg.sender].push(_token_address);
                existing_tokens[msg.sender][_token_address] = id;
            }
        }
        delete portfels[msg.sender][_portfelId];
        return(true);
    }

    function transferPortfelInside(uint256 _portfelId, address recipient) external returns(bool success) {
        require(portfels[msg.sender][_portfelId].adresses.length > 0);
        portfels[recipient].push(portfels[msg.sender][_portfelId]);
        delete portfels[msg.sender][_portfelId];
        return true;
    }

    function getAllowance(address _token_address) external view returns(uint) {
        IERC20 token = IERC20(_token_address);
        return token.allowance(msg.sender, address(this));
    }

    function getAsset(address _token_address, uint256 amount) external returns (bool success) {
        IERC20 token = IERC20(_token_address);
        bool succ = token.transferFrom(msg.sender, address(this), amount);
        if (succ != true) {
            return false;
        }
        balance[msg.sender][_token_address] = balance[msg.sender][_token_address].add(amount);
        if (tokens_collection[msg.sender].length == 0 || existing_tokens[msg.sender][_token_address] == 0 && tokens_collection[msg.sender][0] != _token_address) {
            uint id = tokens_collection[msg.sender].push(_token_address);
            existing_tokens[msg.sender][_token_address] = id;
        }
        return true;
    }

    function sendAsset(address _token_address, address recipient, uint256 amount) external returns(bool success) {
        require(balance[msg.sender][_token_address] >= amount);
        IERC20 token = IERC20(_token_address);
        bool succ = token.transfer(recipient, amount);
        if (succ != true) {
            return false;
        }
        balance[msg.sender][_token_address] = balance[msg.sender][_token_address].sub(amount);
        if (balance[msg.sender][_token_address] == 0) {
            delete tokens_collection[msg.sender][existing_tokens[msg.sender][_token_address]];
            existing_tokens[msg.sender][_token_address] = 0;
        }
        return true;
    }

    function getTokenAddress(address owner) external view returns(address[] memory) {
        return tokens_collection[owner];
    }

    function tokensBalance(address _token_address) external view returns(uint256) {
        return balance[msg.sender][_token_address];
    }

    function transferInside(address _token_address, address recipient, uint256 amount) external returns(bool success) {
        require(balance[msg.sender][_token_address] >= amount);
        balance[msg.sender][_token_address] = balance[msg.sender][_token_address].sub(amount);
        balance[recipient][_token_address] = balance[recipient][_token_address].add(amount);
        if (balance[msg.sender][_token_address] == 0) {
            delete tokens_collection[msg.sender][existing_tokens[msg.sender][_token_address]];
            existing_tokens[msg.sender][_token_address] = 0;
        }
        return true;
    }
}
