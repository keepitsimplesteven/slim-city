# Slim City (working title)

An idle fitness city builder, and a trophy case to commemorate your progress

## Brainstorm

Key features

- Resources based on HealthKit data
    - Start with basic activity data
        - Currencies for calories (as a percentage of your goal), exercise minutes, stand
            - Calories: food
            - Exercise: wood
            - Stand: stone
    - Maybe configurable about what is what?
        - Could use steps, cardio fitness, etc.
- gameplay loop
    - Every morning you get a digest of how the previous day went. You collect up to 100 food (100% of your calorie goal), 30 wood, 12 stone. Food is consumed each day, so you have to keep your baseline calories up otherwise your people will have to ration
    - These can be used to build buildings which improve your kingdom/collection rates
        - House: increases population, increased population demands more food
        - Farm: increases how much food is collected
        - Lumber mill: increases wood
        - Quarry: increases stone
    - Each building can be upgraded to improve xmult
    - Subsequent buildings cost more to create
    - Example:
        - Base food collection is 100. You have a farm which ups the base collection to 110. You upgrade that farm so that all farms grants 1.1x mult. This means that if you close your exercise ring you get 121 the next day, instead of 100
        - Houses will be somewhat expensive by default so population remains a bottleneck. You'll have to ration your workers among the facilities if you want to build better buildings, then go out there and close your rings to cash in
    - Other mechanics
        - Special events? Bounties? Quests? You accept from a board something like "get 1.5x your move goal for 250 food" or "do any 10 minute workout for 1.5x to all resources the next day", randomized
        - Maybe tie into fitness app medals? If you get a "perfect week" award, grants 100/30/12 resources, etc.
        - medals award reskins, visual "street cred"

Building process, loose onboarding setup

Start with a Village Hall: a 2x2(?) building that you can place anywhere in your grid. First thing that shows up when you start a new game. It tells you to go get some exercise and come back later. You come back and build your first house, lumber mill, etc. and the core gameplay loop starts.

Thinking about whether all building should just take 1x1 tile or if they should all be unique, like a house is 2x1, farm is 3x3, quarry is 4x2, etc. This would be more organic, might lead to more frustration. Need an easy reorganize UX. Every asset created using Kenney assets could be at a 1:4 scale, where 1 tile in the game is a 2x2 grid of kenney assets. Will let buildings & such look more detailed without having to change the scale of the game.

Building upgrades

Village hall: Core building for adding new gameplay elements. Upgrades unlock larger build area, new buildings. Maybe 1x around each time? That makes it progressively more valuable as you go

Village hall 1:

House: Upgrade maybe just increases capacity? Can't keep building houses if you have no room

Lumber mill/Sawmill/other future production buildings: Multiplicative boosts to your collection based on how many workers are stationed there. 1-5 star? Infinite with diminishing returns?

Village hall 2:

Mission board (name pending): Gives you randomized tasks to complete.

- Courier: Run 1 mile, gain x resource
- Patrol: Walk 2500 steps, gain x resource
- Maintenance: Complete any strength workout, gain x resource

Village hall 3:

Marketplace: Allows working with other players (networking not yet implemented, nor planned. but it would be cool)

- Say you'll trade wood for stone, when you collect after a set timer (maybe 8 hours? Maybe a day?), you and your partner each gain 25% of the resources the other collected over that timeframe in one lump sum
    - This can be with a "Bot" partner to test viability

Village hall 4:

Records: A place to view village statistics & interesting fitness milestones. It'd relay things like "Your subjects have collected 100000 total food!" or "Your best streak of x was y!"

## other ideas

Networking

- visit other villages, see what friends have built
- Form alliances, boost each others resources. Could be shared goals like "take so many steps as a group for x bonus", or "request wood" where you get like 10% of their next day's yield (they get the full amount still)

### Other Gameplay loops

- currencies update in real-ish time as your rings update? This would mean probably not assigning workers, and instead having a "level 3 quarry requires 10 workers" sort of deal, and you can't build it until there are enough houses

OR

- Pledge how your day is going to go, I.e. when you see your resources, you accept quests, build, allocate workers, then "lock" your choices for the next day. That way you can't game the system and move workers around based on how your resources were collected
    - Maybe a sliding 4 hour window you can configure where you build and allocate & stuff. Like I would set mine from 8-12am

Of those I'd rather them pull from healthkit on app load/refresh. But with the delay it takes before exercise is logged in healthkit users can probably still game the system by logging in and quickly changing the distribution before it updates. Maybe there's a way to track that based on the event time of the workout, not collection time. That way even if they change it before healthkit updates, it won't reflect in already completed exercise.

### development process

Even if the spec seems stable, I'd like to leave a lot of room to tinker and tweak mechanics. Features should be very generically implemented, especially early on, until high level gameplay ideas can be tested. Things like buildings shouldn't be strictly tied to specific upgrades, and should be easy to move around during development

## Questions

What's the chase? What happens when everything's built & upgraded?

- maybe there can be some long term goals set up, like perfect weeks, perfect year (?!) where you earn some cool special building

What does healthkit have access to? Doesn't look like it can read the specific workout badges from the watch (things like perfect week). Will probably have to build those in.
