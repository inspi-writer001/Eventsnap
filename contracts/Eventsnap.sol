// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract EventSnap {
    struct IImage {
        string uploader_selfie;  
        address uploader;        
        bool is_joined;          
        string[] images_uploaded; 
        string[] tag;            // Each index in 'tag' corresponds to the same index in 'images_uploaded'
    }

    struct IEvent {
        string name;                 
        string banner;               
        address owner;              
        address[] attendees;         
        mapping(address => IImage) uploads; // Tracks per-attendee data
    }

    address public owner;      
    uint256 public eventCount; // Track number of events

    mapping(uint256 => IEvent) public events;      // eventId => IEvent
    mapping(uint256 => address[]) private attendeesList; // So we can return attendees easily

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender; 
    }

   
    function createEvent(string memory _name, string memory _banner) public {
        eventCount++;
        events[eventCount].name = _name;
        events[eventCount].banner = _banner;
        events[eventCount].owner = msg.sender;
    }

 
    function joinEvent(uint256 eventId, string memory _uploader_selfie) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        require(!evt.uploads[msg.sender].is_joined, "Already joined this event");

        evt.uploads[msg.sender] = IImage({
            uploader_selfie: _uploader_selfie,
            uploader: msg.sender,
            is_joined: true,
            images_uploaded: new string[](0),
            tag: new string[](0)
        });

        evt.attendees.push(msg.sender);
        attendeesList[eventId].push(msg.sender);
    }

    /**
     * @dev Upload (add) an image and a tag to an event you've joined.
     *      'imageUrl' usually an IPFS CID or any link. 
     *      'tagValue' is the corresponding tag (e.g. "wallet address of a user or email.. to be decided", etc.).
     */
    function uploadImageWithTag(uint256 eventId, string memory imageUrl, string memory tagValue) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        IImage storage userData = evt.uploads[msg.sender];
        require(userData.is_joined, "You must join the event first");

        // Add the image and tag in parallel arrays
        userData.images_uploaded.push(imageUrl);
        userData.tag.push(tagValue);
    }

    /**
     * @dev Delete one of your images (and its corresponding tag) by array index.
     *      - Allowed if caller is:
     *         (a) the image uploader themself,
     *         (b) the event owner, or
     *         (c) the global contract owner.
     *
     */
    function deleteImage(uint256 eventId, uint256 imageIndex) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        IEvent storage evt = events[eventId];

        // Check if the caller is the global contract owner, the event owner, or the image uploader
        bool isAuthorized =
            (msg.sender == owner) ||
            (msg.sender == evt.owner) ||
            (msg.sender == evt.uploads[msg.sender].uploader);

        require(isAuthorized, "Not authorized to delete this image");

        // Ensure the user is part of the event (or is the contract/event owner)
        require(
            evt.uploads[msg.sender].is_joined || msg.sender == owner || msg.sender == evt.owner,
            "Not part of this event"
        );

        // For simplicity, remove from the caller's arrays
        IImage storage userData = evt.uploads[msg.sender];
        uint256 totalImages = userData.images_uploaded.length;
        require(imageIndex < totalImages, "Invalid image index");

        // Remove from images_uploaded by swapping last element, then popping
        if (imageIndex < totalImages - 1) {
            userData.images_uploaded[imageIndex] = userData.images_uploaded[totalImages - 1];
            userData.tag[imageIndex] = userData.tag[totalImages - 1];
        }
        userData.images_uploaded.pop();
        userData.tag.pop();
    }

    /**
     * @dev Delete an entire event from storage. Only the global contract owner can do this.
     */
    function deleteEvent(uint256 eventId) public onlyOwner {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        // Clear out attendees array
        delete attendeesList[eventId];

        // Clear out the event
        delete events[eventId];
    }

    /**
     * @dev Get basic details about an event.
     */
    function getEvent(uint256 eventId)
        public
        view
        returns (
            string memory name,
            string memory banner,
            address eventOwner,
            address[] memory attendees
        )
    {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        return (evt.name, evt.banner, evt.owner, attendeesList[eventId]);
    }

    /**
     * @dev Get all images (and corresponding tags) that a user uploaded for a specific event.
     */
    function getUserImages(uint256 eventId, address user)
        public
        view
        returns (string[] memory, string[] memory)
    {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        require(events[eventId].uploads[user].is_joined, "User not part of this event");

        IImage storage userData = events[eventId].uploads[user];
        return (userData.images_uploaded, userData.tag);
    }
}
