// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract InteractionTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    CreateSubscription public createSubscription;
    FundSubscription public fundSubscription;
    AddConsumer public addConsumer;
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address account;
    address link;

    uint256 public constant FUND_AMOUNT = 3 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        account = config.account;
        link = config.link;

        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();

        vrfCoordinatorMock = VRFCoordinatorV2_5Mock(vrfCoordinator);
    }

    function testCreateSubscription() public {
        // Arrange
        // Act
        (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator, account);
        // Assert
        assert(subId > 0);
    }

    function testFundSubscription() public {
        // Arrange
        // Act
        // Create a subscription
        (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator, account);
        (uint96 balanceBeforeFund,,,,) = vrfCoordinatorMock.getSubscription(subId);
        console.log("Balance before fund: ", balanceBeforeFund);

        // Fund the subscription
        fundSubscription.fundSubscription(vrfCoordinator, subId, link, account);
        (uint96 balanceAfterFund,,,,) = vrfCoordinatorMock.getSubscription(subId);
        console.log("Balance after fund: ", balanceAfterFund);
        // Assert
        assertEq(FUND_AMOUNT * 100, balanceAfterFund - balanceBeforeFund);
    }

    function testAddConsumer() public {
        // Arrange
        // Act
        // Create a subscription
        (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator, account);
        // Fund the subscription
        fundSubscription.fundSubscription(vrfCoordinator, subId, link, account);
        // Don't have tp deploy Raffle again, we already did that in the setUp function
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subId, account);
        // Assert
        (,,,, address[] memory consumers) = vrfCoordinatorMock.getSubscription(subId);
        assertEq(consumers[0], address(raffle));
    }
}
