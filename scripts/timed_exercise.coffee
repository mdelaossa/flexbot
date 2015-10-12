# Description:
#   Hubot script that chooses an exercise at random every X minutes and tells people to do them
#
# Commands:
#   exercise me - Get a random exercise to do
#   hubot add exercise <name> <min> <max> <unit> [imageURL] - Add an exercise to the list
#   hubot remove exercise <name> - Remove exercise <name> from the list
#   hubot list exercises - List all exercise names hubot knows about
#   hubot show exercise <name> - Show info about exercise <name>
#   hubot stop exercising - Stop picking random people to work out
#   hubot start exercising - Start picking random people to work out
#
# Configuration:
#   HUBOT_EXERCISE_ROOM - The room where hubot will automatically tell people to work out
#   HUBOT_EXERCISE_MAX_PEOPLE - Amount of people to choose for workout
#   HUBOT_EXERCISE_MIN_INTERVAL - Minimum interval between workouts. Will be scaled according to active people
#   HUBOT_EXERCISE_MAX_INTERVAL - Maximum interval between workouts. Will be scaled according to active people
#
# Notes:
#   If HUBOT_EXERCISE_ROOM isn't set the bot will not automatically choose work outs until you give it the command
#
# Dependencies:
#   underscore
#

_ = require('underscore')

module.exports = (robot) ->

  exerciseRoom = process.env.HUBOT_EXERCISE_ROOM
  maxPeople = parseInt(process.env.HUBOT_EXERCISE_MAX_PEOPLE, 10) || 3
  minInterval = parseInt(process.env.HUBOT_EXERCISE_MIN_INTERVAL, 10) || 30
  maxInterval = parseInt(process.env.HUBOT_EXERCISE_MAX_INTERVAL, 10) || 40

  exerciseTimeout = null

  if exerciseRoom?
    exerciseTimeout = setTimeout ->
      doAutomaticWorkout()
    , 10 * 1000


    enterReplies = ['Welcome to Camp Hell!', 'Thanks for joining! You will be in shape in no time!', 'Welcome to the gym that never stops!']

    robot.enter (res) ->
      res.send res.random enterReplies

  doAutomaticWorkout = ->
    interval = chooseNextInterval()
    exercise = chooseExercise()
    people = choosePeople().map((user) -> makeMention(user))
    people = ['<!here>'] if Math.random() < 0.10 # 10% of the time, call out the entire channel

    message = "#{people.join(', ')}: Do #{exercise.amount} #{exercise.exercise.unit} of #{exercise.exercise.name} - #{exercise.exercise.image}"

    #robot.messageRoom exerciseRoom, message
    robot.emit 'slack-attachment',
      channel: exerciseRoom,
      text: "Time to workout! Next workout in #{interval} minutes"
      content:
        fallback: message,
        title: "Exercise: #{exercise.exercise.name}",
        thumb_url: exercise.exercise.image,
        fields: [{
          title: 'Amount',
          value: "#{exercise.amount} #{exercise.exercise.unit}",
          short: true
        }, {
          title: 'Assigned to'
          value: people.join(', ')
          short: true
        }]

    exerciseTimeout = setTimeout ->
      doAutomaticWorkout()
    , 1000 * 60 * interval

  chooseNextInterval = ->
    numPeople = activeUsers().length
    numPeople = maxPeople * 4 if ( numPeople > maxPeople*4 )
    scaleFactor = 5 - ( numPeople / maxPeople )
    interval = Math.floor(Math.random() * (maxInterval - minInterval) + minInterval) * scaleFactor

  choosePeople = ->
    users = activeUsers()
    numPeople = users.length
    maxPeople = 1 if numPeople < maxPeople
    _.sample(users, maxPeople)

  chooseExercise = ->
    exercise = _.sample getExercises()
    robot.logger.debug exercise
    min = parseInt(exercise.min, 10)
    max = parseInt(exercise.max, 10)
    amount = Math.floor(Math.random() * (max - min) + min)
    robot.logger.debug "Picked #{amount} reps"
    return { exercise: exercise, amount: amount }

  getExercises = ->
    robot.brain.get('exercises') or []

  getExerciseForName = (name) ->
    _.find getExercises(), name: name

  saveExercise = (name, min, max, unit, image) ->
    exercises = getExercises()
    newExercise =
      name: name
      min: min
      max: max
      unit: unit
      image: image
    exercises.push newExercise
    updateBrain exercises

  removeExercise = (name) ->
    exercises = getExercises()
    exercisesToKeep = _.reject exercises, name: name
    updateBrain exercisesToKeep
    _.find exercises, name: name

  updateBrain = (exercises) ->
    robot.brain.set 'exercises', exercises

  # ===== Slack specific =====
  activeUsers = (channel=exerciseRoom) ->
    robot.logger.debug "Getting channel object for #{channel}"
    channel = robot.adapter.client.getChannelGroupOrDMByName(channel)

    robot.logger.debug "Getting active users in #{channel.name}"

    return (channel.members || [])
    .map( (id) -> robot.adapter.client.users[id] )
    .filter( (user) -> !!user && !user.is_bot && user.presence == 'active' )

  makeMention = (user) ->
    "<@#{user.id}>"


  # ======= ROBOT LISTENERS FROM HERE ON ========

  robot.hear /exercise me/, (res) ->
    chosen = chooseExercise()
    exercise = chosen.exercise
    if exercise
      message = "Do #{chosen.amount} #{exercise.unit} of #{exercise.name}!"
      message = "#{message} - #{exercise.image}" if exercise.image

      robot.emit 'slack-attachment',
        channel: exerciseRoom,
        content:
          fallback: message,
          title: "Exercise: #{exercise.name}",
          thumb_url: exercise.image,
          fields: [{
            title: 'Amount',
            value: "#{chosen.amount} #{exercise.unit}",
            short: true
          }, {
            title: 'Assigned to'
            value: makeMention(res.message.user)
            short: true
          }]

  # name min max unit imageURL
  robot.respond /add exercise (.*) (\d+) (\d+) (\S+)(?: (.*))?/i, (res) ->
    name = res.match[1]
    min = res.match[2]
    max = res.match[3]
    unit = res.match[4]
    image = res.match[5]

    saveExercise name, min, max, unit, image

    res.send "Ok, added exercise #{name} with minimum #{min} and maximum #{max} #{unit}, with image: #{image || 'none'}"

  robot.respond /remove exercise (.*)/i, (res) ->
    name = res.match[1]
    exercise = removeExercise name
    message = "Ok, removed exercise #{exercise.name} with minimum #{exercise.min} and maximum #{exercise.max} #{exercise.unit}, with image: #{exercise.image || 'none'}" if exercise
    res.send message or "Exercise not found"

  robot.respond /list exercises/i, (res) ->
    exercises = getExercises()
    names = _.pluck exercises, 'name'
    res.send "Exercises I know about: #{names.join(', ')}"

  robot.respond /show exercise (.*)/i, (res) ->
    exercise = getExerciseForName(res.match[1])
    message = "#{exercise.name}: Min: #{exercise.min}, Max: #{exercise.max} #{exercise.unit}. Image: #{exercise.image or 'None'}" if exercise
    res.send message or "I don't know about that exercise"

  robot.respond /start exercising/i, (res) ->
    exerciseRoom = res.envelope.room if !exerciseRoom
    doAutomaticWorkout()

  robot.respond /stop exercising/i, (res) ->
    clearTimeout(exerciseTimeout)
    res.send "Stopping automatic workout"

