--!strict
-- Every line of story text in the game.

export type Note = { title: string, body: string, room: string }
export type Ending = { title: string, lines: { string } }

local Story = {}

Story.Intro = {
	"You wake up on a cold floor.",
	"Your head is pounding. You don't remember getting here.",
	"This is Hollow Manor. Your family's house.",
	"Elena. Clara. Ben. Where are they?",
	"Find out what happened to them.",
}

Story.Notes = {
	{
		room = "Library",
		title = "Journal: page 1",
		body = "We moved into Hollow Manor in the autumn. Clara already loves the library and Ben swears the house hums at night.\n\nElena says I work too much. She's right. I'll do better. I promise I'll do better.",
	},
	{
		room = "Study",
		title = "Journal: page 9",
		body = "I haven't slept in six days.\n\nThere is a man in the hallway mirror. He wears my coat. He doesn't blink when I blink.\n\nI covered the mirror with a sheet. This morning the sheet was folded on my desk.",
	},
	{
		room = "Nursery",
		title = "A child's drawing",
		body = "Crayon on paper. A family of four stands in front of the house.\n\nThe tallest figure has been scribbled over in black, pressed so hard the paper tore.\n\nUnderneath, in a child's careful letters:\n\"DADDY'S OTHER FACE\"",
	},
	{
		room = "Kitchen",
		title = "Missing persons notice",
		body = "MISSING: Elena, Clara (9) and Ben (6) MARSH.\nLast seen at Hollow Manor on the night of October 14th.\n\nThe father, Thomas Marsh, has not been located and should not be approached.\n\nA search party will be sent to the manor...",
	},
	{
		room = "Master bedroom",
		title = "Journal: last page",
		body = "I locked it in the mirror room so it can't hurt them anymore.\n\nIf you're reading this: don't open the door. Don't look at the glass.\n\nIt wears my face. It wears my face. It wears my",
	},
} :: { Note }

Story.Objectives = {
	Explore = "Find out what happened to your family",
	MirrorOpen = "A door has opened. The mirror room.",
	Reveal = "Look at yourself.",
	Hunt = "They came looking for you. Don't let them leave.",
	Ending = "",
}

Story.Reveal = {
	"That's you. Just you.",
	"...isn't it?",
	"The notes were in your handwriting.",
	"The thing in the dark was never chasing you.",
	"It was following you. Like a reflection does.",
	"Elena. Clara. Ben. You know where they are.",
	"You always knew.",
}

Story.HuntStart = "Headlights through the windows. The search party is here."

Story.PartyLines = {
	Search = { "Mr. Marsh? Anyone here?", "Stay together.", "Check the rooms.", "Did you hear that?", "This place gives me the creeps." },
	Spotted = { "IT'S HERE!", "RUN!", "What is THAT?!", "Get to the door!", "Oh no, no, no..." },
}

Story.Endings = {
	Perfect = {
		title = "ENDING: A FULL HOUSE",
		lines = {
			"No one from the search party ever came home.",
			"The case went cold. The manor stayed empty.",
			"Almost empty.",
			"Hollow Manor has a family again.",
		},
	},
	Legend = {
		title = "ENDING: THE LEGEND OF HOLLOW MANOR",
		lines = {
			"A few of them made it out, but nobody believed them.",
			"Now kids dare each other to knock on the door at midnight.",
			"You always answer.",
		},
	},
	Exposed = {
		title = "ENDING: THEY'LL BE BACK",
		lines = {
			"Most of them got away. They'll be back with more lights and more people.",
			"Let them come.",
			"The house is patient. So are you.",
		},
	},
} :: { [string]: Ending }

return Story
