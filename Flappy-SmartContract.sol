pragma solidity ^0.8.0;

interface ITRC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FlappyBirdBattle {
    ITRC20 public bttcToken;
    uint256 public stakingAmount;
    bool public useNativeCurrency;
    
    struct Game {
        address player1;
        address player2;
        uint256 player1Score;
        uint256 player2Score;
        bool isCompleted;
        uint256 stake;
    }
    
    mapping(uint256 => Game) public games;
    uint256 public gameCount;
    
    event GameCreated(uint256 gameId, address player1);
    event PlayerJoined(uint256 gameId, address player2);
    event GameCompleted(uint256 gameId, address winner, uint256 prize);
    
    constructor(address _bttcTokenAddress, uint256 _stakingAmount, bool _useNativeCurrency) {
        bttcToken = ITRC20(_bttcTokenAddress);
        stakingAmount = _stakingAmount;
        useNativeCurrency = _useNativeCurrency;
    }
    
    function createGame() external payable {
        if (useNativeCurrency) {
            require(msg.value == stakingAmount, "Incorrect staking amount");
        } else {
            require(bttcToken.transferFrom(msg.sender, address(this), stakingAmount), "Staking failed");
        }
        
        gameCount++;
        games[gameCount] = Game({
            player1: msg.sender,
            player2: address(0),
            player1Score: 0,
            player2Score: 0,
            isCompleted: false,
            stake: stakingAmount
        });
        
        emit GameCreated(gameCount, msg.sender);
    }
    
    function joinGame(uint256 _gameId) external payable {
        Game storage game = games[_gameId];
        require(game.player1 != address(0), "Game does not exist");
        require(game.player2 == address(0), "Game is full");
        require(msg.sender != game.player1, "Cannot join your own game");
        
        if (useNativeCurrency) {
            require(msg.value == stakingAmount, "Incorrect staking amount");
        } else {
            require(bttcToken.transferFrom(msg.sender, address(this), stakingAmount), "Staking failed");
        }
        
        game.player2 = msg.sender;
        emit PlayerJoined(_gameId, msg.sender);
    }
    
    function submitScore(uint256 _gameId, uint256 _score) external {
        Game storage game = games[_gameId];
        require(msg.sender == game.player1 || msg.sender == game.player2, "Not a player in this game");
        require(!game.isCompleted, "Game is already completed");
        
        if (msg.sender == game.player1) {
            game.player1Score = _score;
        } else {
            game.player2Score = _score;
        }
        
        if (game.player1Score > 0 && game.player2Score > 0) {
            completeGame(_gameId);
        }
    }
    
    function completeGame(uint256 _gameId) internal {
        Game storage game = games[_gameId];
        game.isCompleted = true;
        
        address payable winner;
        if (game.player1Score > game.player2Score) {
            winner = payable(game.player1);
        } else if (game.player2Score > game.player1Score) {
            winner = payable(game.player2);
        } else {
            // In case of a tie, return stakes to both players
            if (useNativeCurrency) {
                payable(game.player1).transfer(stakingAmount);
                payable(game.player2).transfer(stakingAmount);
            } else {
                bttcToken.transfer(game.player1, stakingAmount);
                bttcToken.transfer(game.player2, stakingAmount);
            }
            emit GameCompleted(_gameId, address(0), 0);
            return;
        }
        
        uint256 prize = stakingAmount * 2;
        if (useNativeCurrency) {
            winner.transfer(prize);
        } else {
            bttcToken.transfer(winner, prize);
        }
        emit GameCompleted(_gameId, winner, prize);
    }
    
    function withdrawTokens(address _to, uint256 _amount) external {
        require(msg.sender == owner(), "Only owner can withdraw");
        require(bttcToken.transfer(_to, _amount), "Transfer failed");
    }
    
    function withdrawNativeCurrency(address payable _to, uint256 _amount) external {
        require(msg.sender == owner(), "Only owner can withdraw");
        _to.transfer(_amount);
    }
    
    function owner() public view returns (address) {
        return payable(address(uint160(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.coinbase))))));
    }
}
