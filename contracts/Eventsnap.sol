// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract EventSnap {
    // Each individual image entry
    struct UploadedImage {
        string url;    
        string tag;    
        address uploader;
    }

    // Per-user event data
    struct IImage {
        string uploader_selfie;  
        bool is_joined;
        UploadedImage[] images;  // No more parallel arrays
    }

    struct IEvent {
        string name;
        string banner; // IPFS or any URL for the event banner
        address owner; // The event creator
        address[] attendees;
        mapping(address => IImage) uploads; // Tracks each user's images
    }

    address public owner;        // Global contract owner
    uint256 public eventCount;   // Total events created

    mapping(uint256 => IEvent) public events;     
    mapping(uint256 => address[]) private attendeesList; 

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // 1. Create a new event
    function createEvent(string memory _name, string memory _banner) public {
        eventCount++;
        IEvent storage newEvt = events[eventCount];
        newEvt.name = _name;
        newEvt.banner = _banner;
        newEvt.owner = msg.sender;
    }

    // 2. Join an event with a selfie
    function joinEvent(uint256 eventId, string memory _uploader_selfie) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        IImage storage userData = evt.uploads[msg.sender];
        require(!userData.is_joined, "Already joined this event");

        userData.uploader_selfie = _uploader_selfie;
        userData.is_joined = true;

        // Add this user to the attendees array
        evt.attendees.push(msg.sender);
        attendeesList[eventId].push(msg.sender);
    }

    // 3. Upload an image with a tag
    function uploadImageWithTag(
        uint256 eventId, 
        string memory imageUrl, 
        string memory tagValue
    ) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        IEvent storage evt = events[eventId];
        IImage storage userData = evt.uploads[msg.sender];
        require(userData.is_joined, "You must join the event first");

        // Push a new UploadedImage struct into the user's images array
        userData.images.push(UploadedImage({
            url: imageUrl,
            tag: tagValue,
            uploader: msg.sender
        }));
    }

    // 4. Delete a specific image by index
    //    Allowed if caller is the global owner, event owner, or the image uploader.
    function deleteImage(uint256 eventId, uint256 imageIndex) public {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        IEvent storage evt = events[eventId];

        // Check authorization
        bool isContractOwner = (msg.sender == owner);
        bool isEventOwner = (msg.sender == evt.owner);
        
        IImage storage userData = evt.uploads[msg.sender];
        require(userData.is_joined || isContractOwner || isEventOwner, "Not part of this event");

        // Check index in the user's images array
        uint256 totalImages = userData.images.length;
        require(imageIndex < totalImages, "Invalid image index");

        // Ensure the caller is actually the uploader or event/global owner
        UploadedImage memory targetImage = userData.images[imageIndex];
        bool isUploader = (targetImage.uploader == msg.sender);
        require(isUploader || isEventOwner || isContractOwner, "Not authorized to delete this image");

        // Remove by swapping last element into the deleted index, then pop
        if (imageIndex < totalImages - 1) {
            userData.images[imageIndex] = userData.images[totalImages - 1];
        }
        userData.images.pop();
    }

    // 5. Delete an entire event (only the global contract owner)
    function deleteEvent(uint256 eventId) public onlyOwner {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");

        // Clear out attendees array
        delete attendeesList[eventId];

        // Clear out the event
        delete events[eventId];
    }

    // Get event details
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

    // 6. Get all images (and tags) a user uploaded
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

    // 7. OPTIONAL: Get all images from ALL users in a single array
    function getAllEventImages(uint256 eventId) 
        public 
        view 
        returns (UploadedImage[] memory) 
    {
        require(eventId > 0 && eventId <= eventCount, "Invalid event ID");
        IEvent storage evt = events[eventId];
        address[] storage eventAttendees = attendeesList[eventId];

        // 1) Count total images
        uint256 totalImages = 0;
        for (uint256 i = 0; i < eventAttendees.length; i++) {
            totalImages += evt.uploads[eventAttendees[i]].images.length;
        }

        // 2) Create a memory array of the appropriate size
        UploadedImage[] memory allImages = new UploadedImage[](totalImages);
        uint256 index = 0;

        // 3) Fill the array
        for (uint256 i = 0; i < eventAttendees.length; i++) {
            UploadedImage[] storage userImages = evt.uploads[eventAttendees[i]].images;
            for (uint256 j = 0; j < userImages.length; j++) {
                allImages[index] = userImages[j];
                index++;
            }
        }

        return allImages;
    }
}
