;; TravelHub: Decentralized Travel Experience Booking Platform Smart Contract
;; A comprehensive peer-to-peer marketplace enabling travelers to discover, book, and review
;; authentic travel experiences directly with local providers, featuring automated payments,
;; reputation management, and decentralized dispute resolution.

;; Contract administrator
(define-constant contract-administrator tx-sender)

;; System error codes
(define-constant ERR-OWNER-ONLY-ACCESS (err u100))
(define-constant ERR-RESOURCE-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u102))
(define-constant ERR-INVALID-AMOUNT-PROVIDED (err u103))
(define-constant ERR-RESOURCE-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-STATUS-TRANSITION (err u105))
(define-constant ERR-INSUFFICIENT-PAYMENT-AMOUNT (err u106))
(define-constant ERR-BOOKING-DEADLINE-EXPIRED (err u107))
(define-constant ERR-INVALID-RATING-VALUE (err u108))
(define-constant ERR-REVIEW-ALREADY-SUBMITTED (err u109))
(define-constant ERR-BOOKING-NOT-COMPLETED-YET (err u110))
(define-constant ERR-INVALID-INPUT-DATA (err u111))

;; Platform configuration variables
(define-data-var total-experiences-created uint u0)
(define-data-var total-bookings-created uint u0)
(define-data-var platform-commission-rate uint u250) ;; 2.5% represented in basis points

;; Experience lifecycle constants
(define-constant experience-status-active u1)
(define-constant experience-status-inactive u2)
(define-constant experience-status-suspended u3)

;; Booking workflow constants
(define-constant booking-status-pending u1)
(define-constant booking-status-confirmed u2)
(define-constant booking-status-completed u3)
(define-constant booking-status-cancelled u4)
(define-constant booking-status-refunded u5)

;; Core data structures

;; Travel experience registry
(define-map travel-experiences
  { experience-identifier: uint }
  {
    experience-provider: principal,
    experience-title: (string-ascii 100),
    detailed-description: (string-ascii 500),
    experience-location: (string-ascii 100),
    price-per-participant: uint,
    maximum-participants: uint,
    duration-in-hours: uint,
    experience-category: (string-ascii 50),
    current-status: uint,
    completed-bookings-count: uint,
    calculated-average-rating: uint,
    total-reviews-received: uint,
    creation-timestamp: uint
  }
)

;; Customer booking registry
(define-map customer-bookings-registry
  { booking-identifier: uint }
  {
    booked-experience-id: uint,
    booking-customer: principal,
    number-of-participants: uint,
    total-payment-amount: uint,
    booking-creation-date: uint,
    scheduled-experience-date: uint,
    booking-current-status: uint,
    booking-creation-timestamp: uint
  }
)

;; Customer review system
(define-map customer-reviews-registry
  { reviewed-experience-id: uint, reviewing-customer: principal }
  {
    associated-booking-id: uint,
    customer-rating: uint,
    review-comment: (string-ascii 500),
    review-submission-timestamp: uint
  }
)

;; Service provider profiles
(define-map service-provider-profiles
  { provider-principal: principal }
  {
    provider-display-name: (string-ascii 100),
    provider-bio-description: (string-ascii 300),
    total-created-experiences: uint,
    total-completed-bookings: uint,
    provider-average-rating: uint,
    verification-status: bool,
    profile-creation-timestamp: uint
  }
)

;; Customer booking lookup table
(define-map customer-booking-lookup
  { customer-principal: principal, booking-reference-id: uint }
  { referenced-experience-id: uint }
)

;; Experience availability calendar
(define-map experience-availability-calendar
  { target-experience-id: uint, target-date: uint }
  { remaining-available-spots: uint }
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieve specific experience details
(define-read-only (get-travel-experience-details (experience-identifier uint))
  (map-get? travel-experiences { experience-identifier: experience-identifier })
)

;; Retrieve specific booking information
(define-read-only (get-customer-booking-details (booking-identifier uint))
  (map-get? customer-bookings-registry { booking-identifier: booking-identifier })
)

;; Retrieve customer review for experience
(define-read-only (get-customer-review-details (experience-identifier uint) (reviewing-customer principal))
  (map-get? customer-reviews-registry { reviewed-experience-id: experience-identifier, reviewing-customer: reviewing-customer })
)

;; Retrieve service provider profile
(define-read-only (get-service-provider-profile (provider-principal principal))
  (map-get? service-provider-profiles { provider-principal: provider-principal })
)

;; Check experience availability for specific date
(define-read-only (get-experience-availability-status (experience-identifier uint) (target-date uint))
  (map-get? experience-availability-calendar { target-experience-id: experience-identifier, target-date: target-date })
)

;; Get current platform commission rate
(define-read-only (get-current-platform-commission-rate)
  (var-get platform-commission-rate)
)

;; Get platform statistics
(define-read-only (get-platform-statistics)
  {
    total-experiences-created: (var-get total-experiences-created),
    total-bookings-created: (var-get total-bookings-created)
  }
)

;; Calculate total booking price including platform commission
(define-read-only (calculate-total-booking-price (base-amount uint))
  (let ((commission-fee (/ (* base-amount (var-get platform-commission-rate)) u10000)))
    (+ base-amount commission-fee)
  )
)

;; Verify if customer has already reviewed experience
(define-read-only (has-customer-reviewed-experience (experience-identifier uint) (customer-principal principal))
  (is-some (map-get? customer-reviews-registry { reviewed-experience-id: experience-identifier, reviewing-customer: customer-principal }))
)

;; SERVICE PROVIDER MANAGEMENT FUNCTIONS

;; Register new service provider profile
(define-public (register-service-provider-profile (display-name (string-ascii 100)) (bio-description (string-ascii 300)))
  (let ((existing-provider-profile (map-get? service-provider-profiles { provider-principal: tx-sender })))
    (asserts! (> (len display-name) u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len display-name) u100) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len bio-description) u300) ERR-INVALID-INPUT-DATA)
    (if (is-some existing-provider-profile)
      ERR-RESOURCE-ALREADY-EXISTS
      (ok (map-set service-provider-profiles 
        { provider-principal: tx-sender }
        {
          provider-display-name: display-name,
          provider-bio-description: bio-description,
          total-created-experiences: u0,
          total-completed-bookings: u0,
          provider-average-rating: u0,
          verification-status: false,
          profile-creation-timestamp: block-height
        }
      ))
    )
  )
)

;; TRAVEL EXPERIENCE MANAGEMENT FUNCTIONS

;; Create new travel experience listing
(define-public (create-travel-experience-listing 
  (experience-title (string-ascii 100))
  (detailed-description (string-ascii 500))
  (experience-location (string-ascii 100))
  (price-per-participant uint)
  (maximum-participants uint)
  (duration-in-hours uint)
  (experience-category (string-ascii 50))
)
  (let ((new-experience-id (+ (var-get total-experiences-created) u1)))
    (asserts! (> (len experience-title) u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len experience-title) u100) ERR-INVALID-INPUT-DATA)
    (asserts! (> (len detailed-description) u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len detailed-description) u500) ERR-INVALID-INPUT-DATA)
    (asserts! (> (len experience-location) u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len experience-location) u100) ERR-INVALID-INPUT-DATA)
    (asserts! (> (len experience-category) u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len experience-category) u50) ERR-INVALID-INPUT-DATA)
    (asserts! (> price-per-participant u0) ERR-INVALID-INPUT-DATA)
    (asserts! (> maximum-participants u0) ERR-INVALID-INPUT-DATA)
    (asserts! (> duration-in-hours u0) ERR-INVALID-INPUT-DATA)
    
    (begin
      (map-set travel-experiences
        { experience-identifier: new-experience-id }
        {
          experience-provider: tx-sender,
          experience-title: experience-title,
          detailed-description: detailed-description,
          experience-location: experience-location,
          price-per-participant: price-per-participant,
          maximum-participants: maximum-participants,
          duration-in-hours: duration-in-hours,
          experience-category: experience-category,
          current-status: experience-status-active,
          completed-bookings-count: u0,
          calculated-average-rating: u0,
          total-reviews-received: u0,
          creation-timestamp: block-height
        }
      )
      (var-set total-experiences-created new-experience-id)
      
      ;; Update or create provider profile
      (match (map-get? service-provider-profiles { provider-principal: tx-sender })
        existing-profile (map-set service-provider-profiles 
          { provider-principal: tx-sender }
          (merge existing-profile { total-created-experiences: (+ (get total-created-experiences existing-profile) u1) })
        )
        ;; Auto-create basic profile if doesn't exist
        (map-set service-provider-profiles 
          { provider-principal: tx-sender }
          {
            provider-display-name: "",
            provider-bio-description: "",
            total-created-experiences: u1,
            total-completed-bookings: u0,
            provider-average-rating: u0,
            verification-status: false,
            profile-creation-timestamp: block-height
          }
        )
      )
      
      (ok new-experience-id)
    )
  )
)

;; Update experience operational status
(define-public (update-experience-operational-status (experience-identifier uint) (new-operational-status uint))
  (begin
    (asserts! (> experience-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= experience-identifier (var-get total-experiences-created)) ERR-INVALID-INPUT-DATA)
    (match (map-get? travel-experiences { experience-identifier: experience-identifier })
      target-experience
      (if (is-eq (get experience-provider target-experience) tx-sender)
        (if (or (is-eq new-operational-status experience-status-active) 
                (is-eq new-operational-status experience-status-inactive) 
                (is-eq new-operational-status experience-status-suspended))
          (ok (map-set travel-experiences 
            { experience-identifier: experience-identifier }
            (merge target-experience { current-status: new-operational-status })
          ))
          ERR-INVALID-STATUS-TRANSITION
        )
        ERR-UNAUTHORIZED-ACCESS
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; Configure experience availability for specific dates
(define-public (configure-experience-availability (experience-identifier uint) (target-date uint) (available-spots uint))
  (begin
    (asserts! (> experience-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= experience-identifier (var-get total-experiences-created)) ERR-INVALID-INPUT-DATA)
    (asserts! (> target-date u0) ERR-INVALID-INPUT-DATA)
    (match (map-get? travel-experiences { experience-identifier: experience-identifier })
      target-experience
      (if (is-eq (get experience-provider target-experience) tx-sender)
        (if (<= available-spots (get maximum-participants target-experience))
          (ok (map-set experience-availability-calendar
            { target-experience-id: experience-identifier, target-date: target-date }
            { remaining-available-spots: available-spots }
          ))
          ERR-INVALID-AMOUNT-PROVIDED
        )
        ERR-UNAUTHORIZED-ACCESS
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; CUSTOMER BOOKING MANAGEMENT FUNCTIONS

;; Process customer booking request
(define-public (process-customer-booking-request (experience-identifier uint) (number-of-participants uint) (scheduled-experience-date uint))
  (begin
    (asserts! (> experience-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= experience-identifier (var-get total-experiences-created)) ERR-INVALID-INPUT-DATA)
    (asserts! (> number-of-participants u0) ERR-INVALID-INPUT-DATA)
    (asserts! (> scheduled-experience-date u0) ERR-INVALID-INPUT-DATA)
    (match (map-get? travel-experiences { experience-identifier: experience-identifier })
      target-experience
      (let (
        (base-booking-amount (* (get price-per-participant target-experience) number-of-participants))
        (total-booking-amount (calculate-total-booking-price base-booking-amount))
        (new-booking-identifier (+ (var-get total-bookings-created) u1))
        (current-availability (map-get? experience-availability-calendar { target-experience-id: experience-identifier, target-date: scheduled-experience-date }))
      )
        (if (and 
          (is-eq (get current-status target-experience) experience-status-active)
          (<= number-of-participants (get maximum-participants target-experience))
          (> scheduled-experience-date block-height)
        )
          (begin
            ;; Validate and reserve availability
            (asserts! 
              (match current-availability
                availability-data
                (if (>= (get remaining-available-spots availability-data) number-of-participants)
                  (begin
                    (map-set experience-availability-calendar
                      { target-experience-id: experience-identifier, target-date: scheduled-experience-date }
                      { remaining-available-spots: (- (get remaining-available-spots availability-data) number-of-participants) }
                    )
                    true
                  )
                  false
                )
                ;; Initialize availability if not set
                (if (<= number-of-participants (get maximum-participants target-experience))
                  (begin
                    (map-set experience-availability-calendar
                      { target-experience-id: experience-identifier, target-date: scheduled-experience-date }
                      { remaining-available-spots: (- (get maximum-participants target-experience) number-of-participants) }
                    )
                    true
                  )
                  false
                )
              )
              ERR-INSUFFICIENT-PAYMENT-AMOUNT
            )
            
            ;; Create booking record
            (map-set customer-bookings-registry
              { booking-identifier: new-booking-identifier }
              {
                booked-experience-id: experience-identifier,
                booking-customer: tx-sender,
                number-of-participants: number-of-participants,
                total-payment-amount: total-booking-amount,
                booking-creation-date: block-height,
                scheduled-experience-date: scheduled-experience-date,
                booking-current-status: booking-status-pending,
                booking-creation-timestamp: block-height
              }
            )
            
            ;; Create customer lookup entry
            (map-set customer-booking-lookup
              { customer-principal: tx-sender, booking-reference-id: new-booking-identifier }
              { referenced-experience-id: experience-identifier }
            )
            
            ;; Update experience booking statistics
            (map-set travel-experiences
              { experience-identifier: experience-identifier }
              (merge target-experience { completed-bookings-count: (+ (get completed-bookings-count target-experience) u1) })
            )
            
            (var-set total-bookings-created new-booking-identifier)
            (ok new-booking-identifier)
          )
          ERR-INVALID-AMOUNT-PROVIDED
        )
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; Provider confirms pending booking
(define-public (confirm-pending-customer-booking (booking-identifier uint))
  (begin
    (asserts! (> booking-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= booking-identifier (var-get total-bookings-created)) ERR-INVALID-INPUT-DATA)
    (match (map-get? customer-bookings-registry { booking-identifier: booking-identifier })
      target-booking
      (match (map-get? travel-experiences { experience-identifier: (get booked-experience-id target-booking) })
        associated-experience
        (if (is-eq (get experience-provider associated-experience) tx-sender)
          (if (is-eq (get booking-current-status target-booking) booking-status-pending)
            (ok (map-set customer-bookings-registry
              { booking-identifier: booking-identifier }
              (merge target-booking { booking-current-status: booking-status-confirmed })
            ))
            ERR-INVALID-STATUS-TRANSITION
          )
          ERR-UNAUTHORIZED-ACCESS
        )
        ERR-RESOURCE-NOT-FOUND
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; Mark booking as completed after experience
(define-public (mark-booking-as-completed (booking-identifier uint))
  (begin
    (asserts! (> booking-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= booking-identifier (var-get total-bookings-created)) ERR-INVALID-INPUT-DATA)
    (match (map-get? customer-bookings-registry { booking-identifier: booking-identifier })
      target-booking
      (match (map-get? travel-experiences { experience-identifier: (get booked-experience-id target-booking) })
        associated-experience
        (if (is-eq (get experience-provider associated-experience) tx-sender)
          (if (and 
            (is-eq (get booking-current-status target-booking) booking-status-confirmed)
            (<= (get scheduled-experience-date target-booking) block-height)
          )
            (begin
              (map-set customer-bookings-registry
                { booking-identifier: booking-identifier }
                (merge target-booking { booking-current-status: booking-status-completed })
              )
              
              ;; Update provider completion statistics
              (match (map-get? service-provider-profiles { provider-principal: tx-sender })
                provider-profile (map-set service-provider-profiles 
                  { provider-principal: tx-sender }
                  (merge provider-profile { total-completed-bookings: (+ (get total-completed-bookings provider-profile) u1) })
                )
                true ;; Handle missing profile gracefully
              )
              
              (ok true)
            )
            ERR-INVALID-STATUS-TRANSITION
          )
          ERR-UNAUTHORIZED-ACCESS
        )
        ERR-RESOURCE-NOT-FOUND
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; Customer cancels their booking
(define-public (cancel-customer-booking (booking-identifier uint))
  (begin
    (asserts! (> booking-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= booking-identifier (var-get total-bookings-created)) ERR-INVALID-INPUT-DATA)
    (match (map-get? customer-bookings-registry { booking-identifier: booking-identifier })
      target-booking
      (if (is-eq (get booking-customer target-booking) tx-sender)
        (if (and 
          (or (is-eq (get booking-current-status target-booking) booking-status-pending) 
              (is-eq (get booking-current-status target-booking) booking-status-confirmed))
          (> (get scheduled-experience-date target-booking) block-height)
        )
          (begin
            ;; Update booking status
            (map-set customer-bookings-registry
              { booking-identifier: booking-identifier }
              (merge target-booking { booking-current-status: booking-status-cancelled })
            )
            
            ;; Restore availability
            (match (map-get? experience-availability-calendar 
              { target-experience-id: (get booked-experience-id target-booking), target-date: (get scheduled-experience-date target-booking) })
              availability-data
              (map-set experience-availability-calendar
                { target-experience-id: (get booked-experience-id target-booking), target-date: (get scheduled-experience-date target-booking) }
                { remaining-available-spots: (+ (get remaining-available-spots availability-data) (get number-of-participants target-booking)) }
              )
              true ;; Handle missing availability entry
            )
            
            (ok true)
          )
          ERR-INVALID-STATUS-TRANSITION
        )
        ERR-UNAUTHORIZED-ACCESS
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; CUSTOMER REVIEW SYSTEM FUNCTIONS

;; Submit customer review after completed experience
(define-public (submit-customer-experience-review (experience-identifier uint) (booking-identifier uint) (customer-rating uint) (review-comment (string-ascii 500)))
  (begin
    (asserts! (> experience-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= experience-identifier (var-get total-experiences-created)) ERR-INVALID-INPUT-DATA)
    (asserts! (> booking-identifier u0) ERR-INVALID-INPUT-DATA)
    (asserts! (<= booking-identifier (var-get total-bookings-created)) ERR-INVALID-INPUT-DATA)
    (asserts! (<= (len review-comment) u500) ERR-INVALID-INPUT-DATA)
    (match (map-get? customer-bookings-registry { booking-identifier: booking-identifier })
      target-booking
      (if (and 
        (is-eq (get booking-customer target-booking) tx-sender)
        (is-eq (get booked-experience-id target-booking) experience-identifier)
        (is-eq (get booking-current-status target-booking) booking-status-completed)
        (>= customer-rating u1)
        (<= customer-rating u5)
        (not (has-customer-reviewed-experience experience-identifier tx-sender))
      )
        (match (map-get? travel-experiences { experience-identifier: experience-identifier })
          target-experience
          (let (
            (current-review-count (get total-reviews-received target-experience))
            (current-rating-average (get calculated-average-rating target-experience))
            (updated-review-count (+ current-review-count u1))
            (updated-rating-average (/ (+ (* current-rating-average current-review-count) customer-rating) updated-review-count))
          )
            ;; Store customer review
            (map-set customer-reviews-registry
              { reviewed-experience-id: experience-identifier, reviewing-customer: tx-sender }
              {
                associated-booking-id: booking-identifier,
                customer-rating: customer-rating,
                review-comment: review-comment,
                review-submission-timestamp: block-height
              }
            )
            
            ;; Update experience rating statistics
            (map-set travel-experiences
              { experience-identifier: experience-identifier }
              (merge target-experience { 
                calculated-average-rating: updated-rating-average,
                total-reviews-received: updated-review-count
              })
            )
            
            ;; Update provider rating statistics
            (match (map-get? service-provider-profiles { provider-principal: (get experience-provider target-experience) })
              provider-profile
              (let (
                (current-provider-rating (get provider-average-rating provider-profile))
                (updated-provider-rating (if (is-eq current-provider-rating u0) 
                  customer-rating 
                  ;; Simplified moving average calculation
                  (/ (+ current-provider-rating customer-rating) u2)
                ))
              )
                (map-set service-provider-profiles
                  { provider-principal: (get experience-provider target-experience) }
                  (merge provider-profile { provider-average-rating: updated-provider-rating })
                )
              )
              true ;; Handle missing profile gracefully
            )
            
            (ok true)
          )
          ERR-RESOURCE-NOT-FOUND
        )
        ERR-INVALID-RATING-VALUE
      )
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; PLATFORM ADMINISTRATION FUNCTIONS

;; Update platform commission rate (admin only)
(define-public (update-platform-commission-rate (new-commission-rate uint))
  (if (is-eq tx-sender contract-administrator)
    (if (<= new-commission-rate u1000) ;; Maximum 10% commission
      (ok (var-set platform-commission-rate new-commission-rate))
      ERR-INVALID-AMOUNT-PROVIDED
    )
    ERR-OWNER-ONLY-ACCESS
  )
)

;; Grant provider verification status (admin only)
(define-public (grant-provider-verification-status (provider-principal principal))
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERR-OWNER-ONLY-ACCESS)
    ;; Validate that the provider principal is not the zero principal and not empty
    (asserts! (not (is-eq provider-principal 'SP000000000000000000002Q6VF78)) ERR-INVALID-INPUT-DATA)
    ;; Ensure the provider profile exists before attempting to update
    (match (map-get? service-provider-profiles { provider-principal: provider-principal })
      provider-profile
      (ok (map-set service-provider-profiles
        { provider-principal: provider-principal }
        (merge provider-profile { verification-status: true })
      ))
      ERR-RESOURCE-NOT-FOUND
    )
  )
)

;; Suspend experience listing (admin only)
(define-public (suspend-experience-listing (experience-identifier uint))
  (if (is-eq tx-sender contract-administrator)
    (begin
      (asserts! (> experience-identifier u0) ERR-INVALID-INPUT-DATA)
      (asserts! (<= experience-identifier (var-get total-experiences-created)) ERR-INVALID-INPUT-DATA)
      (match (map-get? travel-experiences { experience-identifier: experience-identifier })
        target-experience
        (ok (map-set travel-experiences
          { experience-identifier: experience-identifier }
          (merge target-experience { current-status: experience-status-suspended })
        ))
        ERR-RESOURCE-NOT-FOUND
      )
    )
    ERR-OWNER-ONLY-ACCESS
  )
)