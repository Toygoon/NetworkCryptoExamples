// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Auction {
    uint public reservePrice;
    uint public currentPrice;
    uint public endTime;
    address payable public owner;
    address payable public buyer;
    bool public isActive;
    mapping(address => uint) public refunds;

    // 최대 입찰 가격이 바뀔 때마다, 입찰자와 입찰 가격을 event에 기록하라.
    event PriceChanged(address payable _address, uint _price);
    // 최종 입찰 가격과 입찰자를 event에 등록
    event PriceFinal(address payable _address, uint _price);

    receive() external payable {}

    fallback() external payable {}

    // 생성자 : owner가 실행하며, 희망 가격(uint)과 경매 기간(uint)를 parameter로 전달한다.
    constructor(uint _reservePrice, uint _endTime) {
        reservePrice = _reservePrice;
        currentPrice = 0;
        // 경매 기간은 파이썬의 int(time.time()) 값을 사용하여 계산한다.
        endTime = _endTime;
        owner = payable(msg.sender);
        isActive = true;
    }

    modifier checkActive() {
        // 입찰 시간이 경매 기간을 초과할 경우에도 경매는 종료
        isActive = block.timestamp < endTime;
        require(isActive, "This auction isn't active.");
        _;
    }

    modifier isOwner() {
        // owner가 실행
        require(
            msg.sender == owner,
            "This action is allowed to the owner only."
        );
        _;
    }

    function bid() public payable checkActive {
        // 입찰자가 msg.value에 입찰 가격을 입력하여 실행한다.
        // 입찰 가격이 현재까지의 최대 가격에 미달하면, 실행을 취소한다.
        require(
            currentPrice < msg.value,
            "Reserved price is lower than the current highest price."
        );

        if (msg.value == reservePrice) {
            // 희망 가격을 입찰하는 사람이 있으면 경매는 즉시 종료
            isActive = false;
        }

        if (buyer != address(0)) {
            // 이전의 최대 입찰 가격을 제시한 입찰자에게는 입찰 금액을 즉시 전송한다.
            refunds[buyer] += currentPrice;
        }

        // 입찰 가격을 최대가격에 등록하고, 입찰자도 기록한다.
        buyer = payable(msg.sender);
        currentPrice = msg.value;
        // 최대 입찰 가격이 바뀔 때마다, 입찰자와 입찰 가격을 event에 기록하라.
        emit PriceChanged(buyer, currentPrice);
    }

    function withdraw() public {
        // 환불할 금액이 있는지 확인
        uint refundAmount = refunds[msg.sender];
        require(refundAmount > 0, "No refunds to be made.");

        // mapping 정보 수정
        // 금액을 전송하기 전에 mapping 정보를 수정
        // 이는 re-entrancy 공격을 방지하기 위함이다.
        refunds[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Failed to send refund.");
    }

    function finish() public isOwner {
        // 입찰 종료 조건이 만족될 때만 실행된다.
        require(
            !isActive || block.timestamp >= endTime,
            "This auction can't be finished yet."
        );

        // 최종 입찰 가격과 입찰자를 event에 등록
        emit PriceFinal(buyer, currentPrice);
        owner.transfer(currentPrice);

        isActive = false;
    }
}

contract Owner {
    Auction public auction;

    constructor(uint _reservePrice, uint _endTime) {
        auction = new Auction(_reservePrice, _endTime);
    }

    function getAuctionAddress() public view returns (address) {
        return address(auction);
    }

    function finish() public {
        auction.finish();
    }
}

contract Buyer {
    Auction public auction;

    constructor(address _auction) {
        auction = Auction(payable(_auction));
    }

    function bid() public payable {
        auction.bid{value: msg.value}();
    }

    function claimRefund() public {
        auction.withdraw();
    }
}
