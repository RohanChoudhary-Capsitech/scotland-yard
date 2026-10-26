# Scotland Yard — Game Rules & Modes

## Game Modes

Selected from the main menu:
1. **Play as Detectives**: The player controls the team of detectives; AI controls Mr. X.
2. **Play as Mr. X**: The player controls Mr. X; AI controls all detectives.

---

## Game Rules

### Players & Setup
- **1 Mr. X vs 3–5 Detectives**: Configurable by the player before starting (default is 4 detectives).
- **Starting Stations**: Mr. X and all detectives start at distinct, randomly assigned stations selected from a fixed pool of 18 starting stations defined in `map.json`.

### Tickets & Inventory
- **Transport Types**: `taxi`, `bus`, `underground`, `ferry`.
  - Ferry routes can **only** be traversed using a Black Ticket.
- **Detective Initial Tickets**:
  - 10 Taxi
  - 8 Bus
  - 4 Underground
  - *Note:* Whenever a detective spends a ticket, that ticket is surrendered to Mr. X.
- **Mr. X Initial Tickets**:
  - 4 Taxi
  - 3 Bus
  - 3 Underground
  - Black Tickets = equal to the number of detectives in the match.
  - 2 Double-Move cards.
- **Black Tickets**:
  - Can be used for any transport mode (taxi, bus, underground, ferry).
  - Hides the transport mode used from the detectives.
- **Double Move**:
  - Allows Mr. X to take two consecutive moves in a single turn.
  - Consumes two transport tickets and one double-move card.
  - Both moves and tickets are logged separately in the travel log.

### Turn Structure & Rounds
- **24 Rounds Total**.
- In each round:
  1. Mr. X moves first (or double moves if playing a double-move card).
  2. Each detective takes their turn in fixed sequence.
- **Mr. X Reveal Rounds**: Mr. X surfaces and reveals his exact current station to the detectives after his moves on rounds:
  - **Round 3**
  - **Round 8**
  - **Round 13**
  - **Round 18**
  - **Round 24**
- For all other rounds, Mr. X's position remains hidden (only the transport ticket used is shown).

### Movement Constraints
- Two detectives cannot occupy the same station simultaneously.
- A detective cannot move onto a station currently occupied by another detective.
- If a detective has no legal moves (due to station blocks or lack of matching tickets), their turn is skipped.

### Victory Conditions
- **Detectives Win** if:
  - Any detective lands on the station currently occupied by Mr. X.
  - Mr. X has no legal moves available on his turn (trapped with no valid paths or tickets).
- **Mr. X Wins** if:
  - Mr. X survives all 24 rounds without being caught.
  - No detective is capable of making a move (all detectives are out of tickets or blocked).
