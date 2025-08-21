# TravelHub: Decentralized Travel Experience Booking Platform

## Overview

TravelHub is a comprehensive peer-to-peer marketplace smart contract built on the Stacks blockchain that enables travelers to discover, book, and review authentic travel experiences directly with local providers. The platform features automated payments, reputation management, and decentralized dispute resolution capabilities.

## Key Features

### For Service Providers
- Create and manage travel experience listings
- Set pricing, availability, and experience details
- Manage booking confirmations and completions
- Build reputation through customer reviews
- Profile verification system

### For Customers
- Browse and book travel experiences
- Make secure payments with automatic commission handling
- Submit reviews and ratings after completed experiences
- Cancel bookings before scheduled dates
- Track booking history and status

### Platform Features
- Automated commission collection (2.5% default)
- Real-time availability management
- Reputation and rating system
- Administrative controls for platform management
- Experience categorization and search capabilities

## Contract Architecture

### Core Data Structures

#### Travel Experiences
Stores comprehensive information about each travel experience including:
- Provider details and contact information
- Experience metadata (title, description, location, category)
- Pricing and capacity information
- Current status and booking statistics
- Average ratings and review counts

#### Customer Bookings
Tracks all booking transactions with details such as:
- Experience and customer identification
- Participant count and payment amounts
- Booking and scheduled dates
- Current booking status
- Associated timestamps

#### Reviews and Ratings
Maintains customer feedback system including:
- Star ratings (1-5 scale)
- Written review comments
- Associated booking references
- Submission timestamps

#### Service Provider Profiles
Manages provider information and statistics:
- Display name and biographical information
- Experience creation and completion counts
- Average ratings and verification status
- Profile creation timestamps

## Contract Constants

### Status Codes

#### Experience Status
- `experience-status-active` (1): Experience is available for booking
- `experience-status-inactive` (2): Experience is temporarily unavailable
- `experience-status-suspended` (3): Experience is administratively suspended

#### Booking Status
- `booking-status-pending` (1): Booking awaiting provider confirmation
- `booking-status-confirmed` (2): Booking confirmed by provider
- `booking-status-completed` (3): Experience completed successfully
- `booking-status-cancelled` (4): Booking cancelled by customer
- `booking-status-refunded` (5): Booking refunded (future implementation)

### Error Codes
- `ERR-OWNER-ONLY-ACCESS` (100): Administrative function access denied
- `ERR-RESOURCE-NOT-FOUND` (101): Requested resource does not exist
- `ERR-UNAUTHORIZED-ACCESS` (102): Insufficient permissions for operation
- `ERR-INVALID-AMOUNT-PROVIDED` (103): Invalid numerical input provided
- `ERR-RESOURCE-ALREADY-EXISTS` (104): Resource already exists in system
- `ERR-INVALID-STATUS-TRANSITION` (105): Invalid state change attempted
- `ERR-INSUFFICIENT-PAYMENT-AMOUNT` (106): Payment amount insufficient
- `ERR-BOOKING-DEADLINE-EXPIRED` (107): Booking deadline has passed
- `ERR-INVALID-RATING-VALUE` (108): Rating outside valid range (1-5)
- `ERR-REVIEW-ALREADY-SUBMITTED` (109): Customer has already reviewed experience
- `ERR-BOOKING-NOT-COMPLETED-YET` (110): Booking must be completed before review

## Function Reference

### Read-Only Functions

#### Experience Queries
- `get-travel-experience-details(experience-id)`: Retrieve complete experience information
- `get-experience-availability-status(experience-id, date)`: Check availability for specific date
- `get-platform-statistics()`: Get total experiences and bookings created

#### Booking Queries
- `get-customer-booking-details(booking-id)`: Retrieve complete booking information
- `get-customer-review-details(experience-id, customer)`: Get customer's review for experience

#### Profile Queries
- `get-service-provider-profile(provider)`: Retrieve provider profile information

#### Utility Functions
- `calculate-total-booking-price(base-amount)`: Calculate total price including commission
- `has-customer-reviewed-experience(experience-id, customer)`: Check if customer has reviewed
- `get-current-platform-commission-rate()`: Get current commission percentage

### Service Provider Functions

#### Profile Management
```clarity
(register-service-provider-profile "Display Name" "Bio description")
```
Creates a new service provider profile with display name and biographical information.

#### Experience Management
```clarity
(create-travel-experience-listing 
  "Experience Title"
  "Detailed description of the experience"
  "Location"
  price-per-person
  max-participants
  duration-hours
  "Category"
)
```
Creates a new travel experience listing with all required details.

```clarity
(update-experience-operational-status experience-id new-status)
```
Updates the operational status of an experience (active/inactive/suspended).

```clarity
(configure-experience-availability experience-id date available-spots)
```
Sets availability for specific dates and manages capacity.

#### Booking Management
```clarity
(confirm-pending-customer-booking booking-id)
```
Confirms a pending booking request from a customer.

```clarity
(mark-booking-as-completed booking-id)
```
Marks a booking as completed after the experience has taken place.

### Customer Functions

#### Booking Management
```clarity
(process-customer-booking-request experience-id participants scheduled-date)
```
Creates a new booking request for a travel experience.

```clarity
(cancel-customer-booking booking-id)
```
Cancels an existing booking before the scheduled date.

#### Review System
```clarity
(submit-customer-experience-review experience-id booking-id rating "Review comment")
```
Submits a review and rating for a completed experience.

### Administrative Functions

#### Platform Configuration
```clarity
(update-platform-commission-rate new-rate)
```
Updates the platform commission rate (admin only, maximum 10%).

```clarity
(grant-provider-verification-status provider-principal)
```
Grants verification status to a service provider (admin only).

```clarity
(suspend-experience-listing experience-id)
```
Suspends an experience listing (admin only).

## Usage Examples

### Creating a Travel Experience
```clarity
;; Register as a service provider
(contract-call? .travelhub register-service-provider-profile 
  "Local Adventure Guide" 
  "Experienced guide offering authentic local experiences"
)

;; Create a new experience
(contract-call? .travelhub create-travel-experience-listing
  "Historic City Walking Tour"
  "Discover hidden gems and local history in our 3-hour guided walking tour"
  "Downtown Historic District"
  u50000000 ;; 50 STX per person
  u15       ;; Maximum 15 participants
  u3        ;; 3 hours duration
  "Cultural"
)
```

### Booking an Experience
```clarity
;; Book an experience for 2 people
(contract-call? .travelhub process-customer-booking-request
  u1        ;; Experience ID
  u2        ;; Number of participants
  u1000000  ;; Scheduled date (block height)
)
```

### Submitting a Review
```clarity
;; Submit a 5-star review after completing the experience
(contract-call? .travelhub submit-customer-experience-review
  u1        ;; Experience ID
  u1        ;; Booking ID
  u5        ;; Rating (1-5 stars)
  "Amazing experience! Highly recommend this tour."
)
```

## Platform Economics

### Commission Structure
- Default platform commission: 2.5% (250 basis points)
- Commission is automatically calculated and included in total booking price
- Maximum allowed commission rate: 10% (administrative limit)

### Payment Flow
1. Customer initiates booking with calculated total amount (base price + commission)
2. Funds are held in contract until experience completion
3. Provider confirms booking to proceed
4. Upon completion, funds are distributed according to commission structure

## Security Features

### Access Controls
- Function-level permissions based on user roles
- Provider-only access to their own experiences and bookings
- Customer-only access to their own bookings and reviews
- Administrative functions restricted to contract deployer

### Data Validation
- Input validation for all user-provided data
- Status transition validation for bookings and experiences
- Rating range validation (1-5 stars only)
- Availability checking before booking confirmation

### State Management
- Atomic operations for booking and availability updates
- Consistent state transitions across all contract functions
- Error handling with descriptive error codes

## Development and Testing

### Prerequisites
- Stacks blockchain development environment
- Clarity smart contract testing framework
- Understanding of Stacks transaction lifecycle

### Deployment Considerations
- Contract administrator is set to the deploying principal
- Initial platform commission rate is set to 2.5%
- All counters and statistics start from zero
- No initial data is populated