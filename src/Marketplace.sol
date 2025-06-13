// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract Marketplace is Ownable, ReentrancyGuard {
    
    struct Bid {
        address bidder;      // who made the bid
        uint256 amount;      // amount of the bid
    }

    uint256 public feePercent;
    address public feeRecipient;
    uint256 public maxFeePercent = 1000; // 10% in basis points
    mapping(address => mapping(uint256 => mapping(address => Bid))) public bids; // tokenAddress => tokenId => bidder => Bid

    event FeePercentUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);
    event BidPlaced(address indexed nft, uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidCancelled(address indexed nft, uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidAccepted(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price,
        uint256 fee
    );

    constructor(uint256 feePercent_, address feeRecipient_) Ownable(msg.sender) {
        require(feePercent_ <= maxFeePercent, "Fee too high");
        require(feeRecipient_ != address(0), "Invalid fee recipient");

        feePercent = feePercent_;
        feeRecipient = feeRecipient_;
    }

    function updateFeePercent(uint256 newFee_) external onlyOwner {
        require(newFee_ <= maxFeePercent, "Fee too high");
        feePercent = newFee_;
        emit FeePercentUpdated(newFee_);
    }

    function updateFeeRecipient(address newRecipient_) external onlyOwner {
        require(newRecipient_ != address(0), "Invalid address");
        feeRecipient = newRecipient_;
        emit FeeRecipientUpdated(newRecipient_);
    }


    function makeBid(address nft_, uint256 tokenId_) external payable {
        // 1. Validar que el valor enviado sea mayor a cero
        require(msg.value > 0, "Bid must be greater than 0");

        // 2. Validar que no haya una oferta activa para ese NFT de este usuario
        Bid storage existingBid = bids[nft_][tokenId_][msg.sender];
        require(existingBid.amount == 0, "Active bid already exists");

        // 3. Guardar la oferta
        bids[nft_][tokenId_][msg.sender] = Bid({
            bidder: msg.sender,
            amount: msg.value
        });

        // 4. Emitir el evento
        emit BidPlaced(nft_, tokenId_, msg.sender, msg.value);
    }

    function cancelBid(address nft_, uint256 tokenId_) external nonReentrant {
        // 1. Accedemos a la oferta actual
        Bid memory bid_ = bids[nft_][tokenId_][msg.sender];

        // 2. Validamos que la oferta exista
        require(bid_.amount > 0, "No active bid");

        // 3. Eliminamos la oferta del mapping
        delete bids[nft_][tokenId_][msg.sender];

        // 4. Devolvemos el ETH al ofertante
        (bool success, ) = msg.sender.call{value: bid_.amount}("");
        require(success, "Refund failed");

        // 5. Emitimos el evento
        emit BidCancelled(nft_, tokenId_, msg.sender, bid_.amount);
    }

    function acceptBid(address nft_, uint256 tokenId_, address bidder_) external nonReentrant {
        // 1. Validar que el ofertante haya hecho una oferta
        Bid memory bid_ = bids[nft_][tokenId_][bidder_];
        require(bid_.amount > 0, "No active bid");

        // 2. Validar que quien llama sea el dueño del NFT
        IERC721 nftContract = IERC721(nft_);
        address owner_ = nftContract.ownerOf(tokenId_);
        require(owner_ == msg.sender, "Caller is not NFT owner");

        // 3. Validar que el contrato esté aprobado para transferir el NFT
        require(
            nftContract.getApproved(tokenId_) == address(this) ||
            nftContract.isApprovedForAll(owner_, address(this)),
            "Marketplace not approved"
        );

        // 4. Calcular fee y neto
        uint256 feeAmount_ = (bid_.amount * feePercent) / 10_000;
        uint256 netAmount_ = bid_.amount - feeAmount_;

        // 5. Eliminar la oferta
        delete bids[nft_][tokenId_][bidder_];

        // 6. Transferir NFT al comprador
        nftContract.safeTransferFrom(owner_, bidder_, tokenId_);

        // 7. Enviar ETH al vendedor
        (bool sentSeller, ) = owner_.call{value: netAmount_}("");
        require(sentSeller, "ETH transfer to seller failed");

        // 8. Enviar fee al feeRecipient
        if (feeAmount_ > 0) {
            (bool sentFee, ) = feeRecipient.call{value: feeAmount_}("");
            require(sentFee, "ETH transfer to feeRecipient failed");
        }

        // 9. Emitir evento
        emit BidAccepted(nft_, tokenId_, owner_, bidder_, bid_.amount, feeAmount_);
    }

}
