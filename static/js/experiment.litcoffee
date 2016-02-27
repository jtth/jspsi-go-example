This is a rewrite of the basic go/no-go jspsych experiment implemented in psiturk written in literate CoffeScript.

Current constraints:

- The program only writes data to the server at the end.
- It's a basic experiment that do not do what I want, which is categorization of two different stimuli. We'll get there.

First load psiturk.

	psiturk = new PsiTurk uniqueId, adServerLoc, mode

Then we create blocks for the timeline of the experiment. The first are the text blocks.

This is the first screen the participant sees.

	welcome_block =
		type: "text"
		text: "Welcome to the experiment. Press any key to begin."

When they press a key they are shown some instructions. These are written in HTML. Wait to proceed at least 2 seconds.

	instructions_block =
		type: "text"
		text: "
						<p>In this experiment, a circle will appear in the center of the screen.</p>
					 	<p>If the circle is <strong>blue</strong>, press the letter F on the keyboard as fast as you can.</p>
					 	<p>If the circle is <strong>orange</strong>, do not press any key.</p>
					 	<div class='left center-content'>
					 		<img src='/static/images/blue.png'></img>
				 			<p class='small'><strong>Press the F key</strong></p>
					 	</div>
					 	<div class='right center-content'>
					 		<img src='/static/images/orange.png'></img>
							<p class='small'><strong>Do not press a key</strong></p>
					 	</div>
					 	<p>Press any key to begin.</p>
					"
		timing_post_trial: 2000

Up next are blocks describing the stimuli.

	test_stimuli = [
		{
			stimulus: "/static/images/blue.png"
			data: response: "go"
		}
		{
			stimulus: "/static/images/orange.png"
			data: response: "no-go"
		}
	]

Now we repeat the stimuli 10 times and randomize the trial order for stimuli blocks.

	all_trials = jsPsych.randomization.repeat(test_stimuli, 5)

Next, we create a function to set the gap between trials to have a delay of at least 750ms, with some random interval added to it.

	post_trial_gap = ->
		Math.floor(Math.random() * 1500) + 750

Now we define the test block using the above information. Note the `on_finish` function, which evaluates "correctness." Note that whatever is appended using `jsPsych.data.addDataToLastTrial` does not get sent to `on_data_update` in the call to `jsPsych.init` method down below. Instead, we write that data to `psiturk.recordTrialData` *after* we have modified the last trial's information, then send that data to the server.

This kind of "correct" calculation only requires that the data updating and saving methods be called within the block itself when there is calcuation that has to happen to compute "correct" after the fact. This looks worse, but performs better and makes for cleaner data.

	test_block =
		type: "single-stim" 								# this is a type of testing block in jsPsych
		choices: ['F']											# still needs to be defined as an array
		timing_response: 1500
		timing_post_trial: post_trial_gap		# this calls our randomized timing function between trials
		on_finish: (data) ->
			correct = false
			correct = true if data.response == 'go' and data.rt > -1
			correct = true if data.response == 'no-go' and data.rt == -1
			jsPsych.data.addDataToLastTrial({correct: correct})
			psiturk.recordTrialData(jsPsych.data.getLastTrialData())
			psiturk.saveData()
			return
		timeline: all_trials								# as defined above

For the last part of our timeline construct, we want to debrief participants. The function needs parens because it takes no arguments.

	debrief_block =
	  type: 'text'
	  text: ->
	    subject_data = getSubjectData()
	    '<p>You responded correctly on ' + subject_data.accuracy + '% of ' + 'the trials.</p>
			<p>Your average response time was <strong>' + subject_data.rt + 'ms</strong>. Press any key to complete the ' + 'experiment. Thank you!</p>'

Now we define the function we used above. We compute accuracy and reaction time for correct 'go' responses, then return both in an object.

	getSubjectData = ->
	  trials = jsPsych.data.getTrialsOfType('single-stim')
	  sum_rt = 0
	  correct_trial_count = 0
	  correct_rt_count = 0
	  i = 0
	  while i < trials.length
	    if trials[i].correct == true
	      correct_trial_count++
	      if trials[i].rt > -1
	        sum_rt += trials[i].rt
	        correct_rt_count++
	    i++
	  {
	    rt: Math.floor(sum_rt / correct_rt_count)
	    accuracy: Math.floor(correct_trial_count / trials.length * 100)
	  }
	# ---
	# generated by js2coffee 2.1.0

Now we define the experimental timeline using the blocks we created above.

	experiment_blocks = [
		welcome_block
		instructions_block
		test_block
		debrief_block
	]

Finally we combine everything to a call to jsPsych to create an experiment. `$('#jspsych-target')` is a jquery call to the named div element in the `exp.html` page.

	jsPsych.init
		display_element: $('#jspsych-target')
		timeline: experiment_blocks
		# show_progress_bar: true
		on_finish: ->
			# jsPsych.data.displayData()
			psiturk.saveData success: ->
				psiturk.completeHIT() # parens required b/c no passed value
				return
			return
		# on_data_update: (data) ->
		# 	console.log(data)
		# 	#psiturk.recordTrialData(data)
		# 	return
