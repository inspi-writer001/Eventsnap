// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract EventSnap {
    using Strings for uint256;

    struct UploadedImage {
        string url;    
        string tag;    
        address uploader;
    }

    struct IImage {
        string uploader_selfie;  
        bool is_joined;
        UploadedImage[] images;  // Each image is now a struct, no parallel arrays
    }

    struct IEvent {
        string uid;           // Unique ID for the event (e.g., "EVENT_1")
        string name;
        string banner; 
        address owner; 
        address[] attendees;
        mapping(address => IImage) uploads; // Tracks each user's images
        string[] highlightImages;           // Highlights for the event (set by oracle)
    }

    address public owner;        // Global contract owner
    address public oracle;       // Authorized oracle address for setting highlights
    uint256 public eventCount;   // Total events created

    mapping(uint256 => IEvent) public events;     
    mapping(uint256 => address[]) private attendeesList; 

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }
    
    modifier onlyOracle() {
        require(msg.sender == oracle, "Not authorized: Only oracle can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        oracle = msg.sender;
    }


    /**
     * @dev Allows the owner to update the oracle address.
     */
    function setOracle(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "Invalid oracle address");
        oracle = _newOracle;
    }


    /**
     * @dev Creates an event, increments the counter, generates a unique UID,
     * and returns the UID.
     */
    function createEvent(string memory _name, string memory _banner) public returns (string memory) {
        eventCount++;
        IEvent storage newEvt = events[eventCount];
        newEvt.name = _name;
        newEvt.banner = _banner;
        newEvt.owner = msg.sender;
        newEvt.uid = string(abi.encodePacked("EVENT_", eventCount.toString()));
        return newEvt.uid;
    }

    /**
     * @dev Allows a user to join an event by providing their selfie.
     */
    function joinEvent(uint256 eventId, string memory _uploader_selfie) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        IImage storage userData = evt.uploads[msg.sender];
        require(!userData.is_joined, "Already joined this event");

        userData.uploader_selfie = _uploader_selfie;
        userData.is_joined = true;
        
        evt.attendees.push(msg.sender);
        attendeesList[eventId].push(msg.sender);
    }

    /**
     * @dev Uploads an image with an associated tag.
     */
    function uploadImageWithTag(uint256 eventId, string memory imageUrl, string memory tagValue) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        IImage storage userData = evt.uploads[msg.sender];
        require(userData.is_joined, "You must join the event first");

        userData.images.push(UploadedImage({
            url: imageUrl,
            tag: tagValue,
            uploader: msg.sender
        }));
    }

    /**
     * @dev Deletes one image (and its tag) from a user's uploads.
     */
    function deleteImage(uint256 eventId, uint256 imageIndex) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        IEvent storage evt = events[eventId];

        bool isContractOwner = (msg.sender == owner);
        bool isEventOwner = (msg.sender == evt.owner);
        
        IImage storage userData = evt.uploads[msg.sender];
        require(userData.is_joined || isContractOwner || isEventOwner, "Not part of this event");

        uint256 totalImages = userData.images.length;
        require(imageIndex < totalImages, "Invalid image index");

        UploadedImage memory targetImage = userData.images[imageIndex];
        bool isUploader = (targetImage.uploader == msg.sender);
        require(isUploader || isEventOwner || isContractOwner, "Not authorized to delete this image");

        if (imageIndex < totalImages - 1) {
            userData.images[imageIndex] = userData.images[totalImages - 1];
        }
        userData.images.pop();
    }

    /**
     * @dev Deletes an entire event. Only the global contract owner can do this.
     */
    function deleteEvent(uint256 eventId) public onlyOwner {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        delete attendeesList[eventId];
        delete events[eventId];
    }

    /**
     * @dev Returns event details, including its UID.
     */
    function getEvent(uint256 eventId)
        public
        view
        returns (
            string memory uid,
            string memory name,
            string memory banner,
            address eventOwner,
            address[] memory attendees
        )
    {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        return (evt.uid, evt.name, evt.banner, evt.owner, attendeesList[eventId]);
    }

    /**
     * @dev Returns all images (and tags) a user has uploaded for a specific event.
     */
    function getUserImages(uint256 eventId, address user)
        public
        view
        returns (UploadedImage[] memory)
    {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        IImage storage userData = events[eventId].uploads[user];
        require(userData.is_joined, "User not part of this event");
        return userData.images;
    }

    /**
     * @dev Returns all images (and tags) from all attendees of an event.
     */
    function getAllEventImages(uint256 eventId) public view returns (UploadedImage[] memory) {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        IEvent storage evt = events[eventId];
        address[] storage eventAttendees = attendeesList[eventId];

        uint256 totalImages = 0;
        for (uint256 i = 0; i < eventAttendees.length; i++) {
            totalImages += evt.uploads[eventAttendees[i]].images.length;
        }

        UploadedImage[] memory allImages = new UploadedImage[](totalImages);
        uint256 index = 0;
        for (uint256 i = 0; i < eventAttendees.length; i++) {
            UploadedImage[] storage userImages = evt.uploads[eventAttendees[i]].images;
            for (uint256 j = 0; j < userImages.length; j++) {
                allImages[index] = userImages[j];
                index++;
            }
        }
        return allImages;
    }

    /**
     * @dev Sets the highlight images for an event. Only the designated oracle can call this.
     */
   function setHighlights(uint256 eventId, string[] calldata highlights) external onlyOracle {
    require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
    IEvent storage evt = events[eventId];
    // Clear the current array
    delete evt.highlightImages;
    // Manually copy each element from calldata to storage
    for (uint256 i = 0; i < highlights.length; i++) {
        evt.highlightImages.push(highlights[i]);
    }
}

    /**
     * @dev Retrieves the highlight images for an event.
     */
    function getHighlights(uint256 eventId) public view returns (string[] memory) {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        return events[eventId].highlightImages;
    }
}
