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
#
# Notes:
#   If HUBOT_EXERCISE_ROOM isn't set the bot will not automatically choose work outs
#
# Dependencies:
#   underscore
#

_ = require('underscore')

module.exports = (robot) ->

  exerciseRoom = process.env.HUBOT_EXERCISE_ROOM

  exerciseTimeout = null

  if exerciseRoom?
    exerciseTimeout = setTimeout ->
      robot.messageRoom 'flexbot-test', 'Do an exercise'
    , 10 * 1000


    enterReplies = ['Welcome to Camp Hell!', 'Thanks for joining! You will be in shape in no time!', 'Welcome to the gym that never stops!']

    robot.enter (res) ->
      res.send res.random enterReplies

  chooseExercise = ->
    exercise = chooseRandomFromArray getExercises()
    robot.logger.debug exercise
    min = parseInt(exercise.min, 10)
    max = parseInt(exercise.max, 10)
    amount = Math.floor(Math.random() * (max - min) + min)
    robot.logger.debug "Picked #{amount} reps"
    return { exercise: exercise, amount: amount }

  activeUsers = (channel) ->
    channel = exerciseRoom if !channel
    channel = robot.adapter.client.getChannelGroupOrDMByName(channel)

    robot.logger.debug "Getting active users in #{channel.name}"

    return (channel.members || [])
    .map( (id) -> robot.adapter.client.users[id] )
    .filter( (user) -> !!user && !user.is_bot && user.presence == 'active' )

  chooseRandomFromArray = (array) ->
    array[Math.floor(Math.random() * array.length)]

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


  # ======= ROBOT LISTENERS FROM HERE ON ========

  robot.hear /exercise me/, (res) ->
    chosen = chooseExercise()
    exercise = chosen.exercise
    if exercise
      message = "Do #{chosen.amount} #{exercise.unit} of #{exercise.name}!"
      message = "#{message} - #{exercise.image}" if exercise.image
    res.reply message or "No exercises in list! Add some with the 'add exercise' command"

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

