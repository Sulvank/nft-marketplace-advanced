// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract FailingBidder {
    Marketplace public marketplace;
    address public nft;

    constructor(Marketplace _marketplace, address _nft) {
        marketplace = _marketplace;
        nft = _nft;
    }

    // Rechazar ETH
    receive() external payable {
        revert("I don't accept ETH");
    }

    function makeBid() external payable {
        marketplace.makeBid{value: msg.value}(nft, 1);
    }

    function cancelMyBid() external {
        marketplace.cancelBid(nft, 1);
    }
}

contract RejectsETHAndCallsAccept {
    receive() external payable {
        revert("no ETH for me");
    }

    function accept(Marketplace marketplace, address nft_, uint256 tokenId_, address bidder_) external {
        marketplace.acceptBid(nft_, tokenId_, bidder_);
    }
}



contract MarketplaceTest is Test {


    Marketplace public marketplace;
    TestERC721 public nft;

    address owner = address(this);
    address bidder = vm.addr(1);

    event FeePercentUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);
    event BidPlaced(address indexed nft, uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidCancelled(address indexed nft, uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidAccepted(address indexed nft, uint256 indexed tokenId, address indexed seller, address buyer, uint256 price, uint256 fee);


    function setUp() public {
        marketplace = new Marketplace(250, address(0xdead)); // 2.5% fee
        nft = new TestERC721();

        // Mint NFT al owner (este contrato)
        nft.mint(owner, 1);

        // Bidder recibe ETH para test
        vm.deal(bidder, 10 ether);

        // Approve marketplace para transferir NFT en nombre del owner
        nft.setApprovalForAll(address(marketplace), true);
    }

    receive() external payable {}


    function testConstructorInitializesCorrectly() public {
        Marketplace m_ = new Marketplace(250, address(0xBEEF));

        assertEq(m_.feePercent(), 250);
        assertEq(m_.feeRecipient(), address(0xBEEF));
    }

    function testFeePencentTooHigh() public {
        vm.expectRevert("Fee too high");
        new Marketplace(1001, address(0xBEEF)); // 10.01% fee
    }

    function testFeeRecipientCannotBeZero() public {
        vm.expectRevert("Invalid fee recipient");
        new Marketplace(250, address(0)); // 2.5% fee with zero address
    }

    function testUpdateFeePercentWorks() public {
        // Check valor inicial
        assertEq(marketplace.feePercent(), 250);

        // Llamada del owner para actualizarlo a 500 (5%)
        vm.expectEmit(true, false, false, true);
        emit FeePercentUpdated(500);
        marketplace.updateFeePercent(500);

        assertEq(marketplace.feePercent(), 500);
    }

    function testUpdateFeePercentFailsIfNotOwner() public {
        vm.prank(bidder); // no es el owner
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bidder));

        marketplace.updateFeePercent(400);
    }

    function testUpdateFeePercentFailsIfTooHigh() public {
        vm.expectRevert("Fee too high");
        marketplace.updateFeePercent(1001); // 10.01% fee
    }

    function testUpdateFeeRecipientWorks() public {
        address newRecipient_ = address(0xBEEF);

        vm.expectEmit(true, false, false, true);
        emit FeeRecipientUpdated(newRecipient_);
        marketplace.updateFeeRecipient(newRecipient_);

        assertEq(marketplace.feeRecipient(), newRecipient_);
    }

    function testUpdateFeeRecipientsFailsIfZeroAddress() public {
        vm.expectRevert("Invalid address");
        marketplace.updateFeeRecipient(address(0)); // Zero address
    }

    function testUpdateFeeRecipientFailsIfNotOwner() public {
        vm.prank(bidder); // no es el owner
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", bidder));
        marketplace.updateFeeRecipient(address(0xC0FFEE));
    }

    function testMakeBidWorks() public {
        vm.prank(bidder);
        vm.deal(bidder, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit BidPlaced(address(nft), 1, bidder, 1 ether);

        marketplace.makeBid{value: 1 ether}(address(nft), 1);

        (address storedBidder, uint256 amount) = marketplace.bids(address(nft), 1, bidder);
        assertEq(storedBidder, bidder);
        assertEq(amount, 1 ether);
    }

    function testMakeBidFailsIfZeroValue() public {
        vm.prank(bidder);
        vm.expectRevert("Bid must be greater than 0");
        marketplace.makeBid{value: 0}(address(nft), 1);
    }

    function testMakeBidFailsIfBidAlreadyExists() public {
        vm.prank(bidder);
        vm.deal(bidder, 2 ether);

        marketplace.makeBid{value: 1 ether}(address(nft), 1);

        vm.prank(bidder);
        vm.expectRevert("Active bid already exists");
        marketplace.makeBid{value: 1 ether}(address(nft), 1);
    }

    function testCancelBidWorks() public {
        // 1. Simular oferta previa
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        marketplace.makeBid{value: 1 ether}(address(nft), 1);

        // 2. Cancelar oferta
        vm.expectEmit(true, true, true, true);
        emit BidCancelled(address(nft), 1, bidder, 1 ether);

        uint256 balanceBefore_ = bidder.balance;

        vm.prank(bidder);
        marketplace.cancelBid(address(nft), 1);

        // 3. Validar que se eliminó
        (address storedBidder, uint256 amount) = marketplace.bids(address(nft), 1, bidder);
        assertEq(storedBidder, address(0));
        assertEq(amount, 0);

        // 4. Validar que recuperó los fondos
        uint256 balanceAfter_ = bidder.balance;
        assertEq(balanceAfter_ - balanceBefore_, 1 ether);
    }

    function testCancelBidFailsIfNoBid() public {
        vm.prank(bidder);
        vm.expectRevert("No active bid");
        marketplace.cancelBid(address(nft), 1);
    }

    function testCancelBidRevertsIfRefundFails() public {
        FailingBidder badUser = new FailingBidder(marketplace, address(nft));
        vm.deal(address(badUser), 1 ether);

        // Hacer bid desde el contrato "rebelde"
        badUser.makeBid{value: 1 ether}();

        // Esperamos revert por fallo de refund
        vm.expectRevert("Refund failed");
        badUser.cancelMyBid();
    }

    function testAcceptBidWorks() public {
        // Preparar: bidder hace una oferta de 1 ETH
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        marketplace.makeBid{value: 1 ether}(address(nft), 1);

        // Confirmar propiedad inicial
        assertEq(nft.ownerOf(1), owner);

        uint256 balanceBeforeOwner_ = owner.balance;
        uint256 balanceBeforeFee_ = address(0xdead).balance;

        vm.expectEmit(true, true, true, true);
        emit BidAccepted(address(nft), 1, owner, bidder, 1 ether, 0.025 ether);

        // Ejecutar acceptBid desde el dueño del NFT
        marketplace.acceptBid(address(nft), 1, bidder);

        // Validaciones
        assertEq(nft.ownerOf(1), bidder); // NFT ahora es del comprador
        assertEq(owner.balance - balanceBeforeOwner_, 0.975 ether); // Recibe el neto
        assertEq(address(0xdead).balance - balanceBeforeFee_, 0.025 ether); // Fee enviado correctamente

        // Confirmar que el bid fue eliminado
        (address storedBidder, uint256 amount) = marketplace.bids(address(nft), 1, bidder);
        assertEq(storedBidder, address(0));
        assertEq(amount, 0);
    }

    function testAcceptBidFailsIfNotOwner() public {
        // Hacer bid
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        marketplace.makeBid{value: 1 ether}(address(nft), 1);

        // Simular que otro (no el owner) intenta aceptar
        vm.prank(bidder);
        vm.expectRevert("Caller is not NFT owner");
        marketplace.acceptBid(address(nft), 1, bidder);
    }

    function testAcceptBidFailsIfNotApproved() public {
        // Eliminar la aprobación
        nft.setApprovalForAll(address(marketplace), false);

        // Hacer bid
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        marketplace.makeBid{value: 1 ether}(address(nft), 1);

        // Intentar aceptar sin approval
        vm.expectRevert("Marketplace not approved");
        marketplace.acceptBid(address(nft), 1, bidder);
    }

    function testAcceptBidFailsIfNoBid() public {
        vm.expectRevert("No active bid");
        marketplace.acceptBid(address(nft), 1, bidder);
    }

    function testAcceptBidRevertsIfFeeRecipientFails() public {
        // 1. Crear feeRecipient que rechaza ETH
        RejectsETHAndCallsAccept badRecipient = new RejectsETHAndCallsAccept();

        // 2. Crear un nuevo marketplace con ese recipient
        Marketplace badMarketplace = new Marketplace(250, address(badRecipient));

        // 3. Mint NFT al test y aprobar
        TestERC721 testNFT = new TestERC721();
        testNFT.mint(address(this), 1);
        testNFT.setApprovalForAll(address(badMarketplace), true);

        // 4. Hacer una oferta desde otro user
        address testBidder = vm.addr(1234);
        vm.deal(testBidder, 1 ether);
        vm.prank(testBidder);
        badMarketplace.makeBid{value: 1 ether}(address(testNFT), 1);

        // 5. Esperamos revert al intentar aceptar
        vm.expectRevert("ETH transfer to feeRecipient failed");
        badMarketplace.acceptBid(address(testNFT), 1, testBidder);
    }

    function testAcceptBidRevertsIfSendToSellerFails() public {
        // 1. Crear contrato que va a fallar al recibir ETH
        RejectsETHAndCallsAccept badSeller = new RejectsETHAndCallsAccept();

        // 2. Mint NFT a ese contrato
        nft.mint(address(badSeller), 77);

        // 3. Aprobar al marketplace para transferir el NFT
        vm.prank(address(badSeller));
        nft.approve(address(marketplace), 77);

        // 4. El bidder hace una oferta
        vm.deal(bidder, 1 ether);
        vm.prank(bidder);
        marketplace.makeBid{value: 1 ether}(address(nft), 77);

        // 5. Esperamos revert por fallo en envío de ETH al vendedor
        vm.expectRevert("ETH transfer to seller failed");

        // 6. Ejecutar acceptBid desde el vendedor
        vm.prank(address(badSeller));
        badSeller.accept(marketplace, address(nft), 77, bidder);
    }


}   
