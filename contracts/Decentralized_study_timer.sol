// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Minimal ERC20 Token for Study Rewards
contract StudyTimerToken {
    string public name = "StudyTime";
    string public symbol = "STUDY";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        _mint(owner, 1_000_000 * 10 ** uint256(decimals));
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }
}

/// @title Minimal NFT Contract for Study Badges
contract StudyBadgeNFT {
    string public name = "StudyBadge";
    string public symbol = "SBADGE";
    uint256 public nextTokenId;
    address public owner;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public tokensOf;
    mapping(uint256 => string) public tokenURIs;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function mintBadge(address to, string memory uri) external onlyOwner {
        uint256 tokenId = nextTokenId++;
        ownerOf[tokenId] = to;
        tokensOf[to].push(tokenId);
        tokenURIs[tokenId] = uri;
        emit Transfer(address(0), to, tokenId);
    }
}

/// @title DecentralizedStudyTimer - Study Tracking with Rewards, Badges, and Group Challenges
contract DecentralizedStudyTimer {
    StudyTimerToken public token;
    StudyBadgeNFT public badgeNFT;
    address public owner;
    uint256 public rewardPerMinute = 1 * 10**18;

    struct Session {
        uint256 startTime;
        uint256 totalDuration;
        bool active;
    }

    struct UserProfile {
        string username;
        uint256 totalStudyTime;
        uint256 lastSessionEnd;
        uint256 badgeCount;
        address user;
    }

    struct Group {
        string name;
        address[] members;
        uint256 totalTime;
        bool exists;
    }

    mapping(address => Session) public sessions;
    mapping(address => UserProfile) public profiles;
    mapping(string => Group) public groups;
    address[] public users;
    string[] public groupNames;

    modifier onlyRegistered() {
        require(bytes(profiles[msg.sender].username).length > 0, "Register first");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not admin");
        _;
    }

    constructor(address _tokenAddress, address _badgeNFT) {
        token = StudyTimerToken(_tokenAddress);
        badgeNFT = StudyBadgeNFT(_badgeNFT);
        owner = msg.sender;
    }

    function register(string memory _username) external {
        require(bytes(profiles[msg.sender].username).length == 0, "Already registered");
        profiles[msg.sender] = UserProfile(_username, 0, 0, 0, msg.sender);
        users.push(msg.sender);
    }

    function startSession() external onlyRegistered {
        Session storage s = sessions[msg.sender];
        require(!s.active, "Session already active");
        s.startTime = block.timestamp;
        s.active = true;
    }

    function stopSession() external onlyRegistered {
        Session storage s = sessions[msg.sender];
        require(s.active, "No active session");

        uint256 duration = block.timestamp - s.startTime;
        s.totalDuration += duration;
        s.active = false;

        UserProfile storage user = profiles[msg.sender];
        user.totalStudyTime += duration;
        user.lastSessionEnd = block.timestamp;

        uint256 reward = (duration / 60) * rewardPerMinute;
        if (reward > 0) token.mint(msg.sender, reward);

        if (user.totalStudyTime >= 5 hours && user.badgeCount == 0) {
            badgeNFT.mintBadge(msg.sender, "ipfs://badge1uri");
            user.badgeCount++;
        } else if (user.totalStudyTime >= 20 hours && user.badgeCount == 1) {
            badgeNFT.mintBadge(msg.sender, "ipfs://badge2uri");
            user.badgeCount++;
        }
    }

    function getLeaderboard() external view returns (address[] memory topUsers, uint256[] memory times) {
        uint256 len = users.length;
        topUsers = new address[](len);
        times = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            topUsers[i] = users[i];
            times[i] = profiles[users[i]].totalStudyTime;
        }

        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (times[j] > times[i]) {
                    (times[i], times[j]) = (times[j], times[i]);
                    (topUsers[i], topUsers[j]) = (topUsers[j], topUsers[i]);
                }
            }
        }
    }

    function createGroup(string memory groupName) external onlyRegistered {
        require(!groups[groupName].exists, "Group exists");
        Group storage g = groups[groupName];
        g.name = groupName;
        g.members.push(msg.sender);
        g.exists = true;
        groupNames.push(groupName);
    }

    function joinGroup(string memory groupName) external onlyRegistered {
        require(groups[groupName].exists, "Group not found");
        Group storage g = groups[groupName];
        g.members.push(msg.sender);
    }

    function getMyStudyTime() external view onlyRegistered returns (uint256) {
        return profiles[msg.sender].totalStudyTime;
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardPerMinute = newRate;
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        token.transfer(to, amount);
    }
}
