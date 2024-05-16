/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _CONTROLS_H_
#define _CONTROLS_H_

#define S9xNoMapping			0
#define S9xButtonJoypad			1
#define S9xButtonMouse			2
#define S9xButtonSuperscope		3
#define S9xButtonJustifier		4
#define S9xButtonCommand		5
#define S9xButtonMulti			6
#define S9xButtonMacsRifle		7
#define S9xAxisJoypad			8
#define S9xPointer				9

#define S9xButtonPseudopointer	254
#define S9xAxisPseudopointer	253
#define S9xAxisPseudobuttons	252

// These are automatically kicked out to the S9xHandlePortCommand function.
// If your port wants to define port-specific commands or whatever, use these values for the s9xcommand_t type field.

#define S9xButtonPort			251
#define S9xAxisPort				250
#define S9xPointerPort			249

#define S9xBadMapping			255
#define InvalidControlID		((uint32) -1)

// S9xButtonPseudopointer and S9xAxisPseudopointer will report pointer motion using IDs PseudoPointerBase through PseudoPointerBase+7.
// S9xAxisPseudopointer command types. S9xAxisPseudobuttons will report buttons with IDs PseudoButtonBase to PseudoButtonBase+255.

#define PseudoPointerBase		(InvalidControlID - 8)
#define PseudoButtonBase		(PseudoPointerBase - 256)

typedef struct
{
	uint8	type;
	uint8	multi_press:2;
	uint8	button_norpt:1;

	union
	{
		union
		{
			struct
			{
				uint8	idx:3;				// Pad number 0-7
				uint8	toggle:1;			// If set, toggle turbo/sticky for the button
				uint8	turbo:1;			// If set, be a 'turbo' button
				uint8	sticky:1;			// If set, toggle button state (on/turbo or off) when pressed and do nothing on release
				uint16	buttons;			// Which buttons to actuate. Use SNES_*_MASK constants from snes9x.h
			}	joypad;

			struct
			{
				uint8	idx:1;				// Mouse number 0-1
				uint8	left:1;				// buttons
				uint8	right:1;
			}	mouse;

			struct
			{
				uint8	fire:1;
				uint8	cursor:1;
				uint8	turbo:1;
				uint8	pause:1;
				uint8	aim_offscreen:1;	// Pretend we're pointing the gun offscreen (ignore the pointer)
			}	scope;

			struct
			{
				uint8	idx:3;				// Pseudo-pointer number 0-7
				uint8	speed_type:2;		// 0=variable, 1=slow, 2=med, 3=fast
				int8	UD:2;				// -1=up, 1=down, 0=no vertical motion
				int8	LR:2;				// -1=left, 1=right, 0=no horizontal motion
			}	pointer;

			struct
			{
				uint8	idx:1;				// Justifier number 0-1
				uint8	trigger:1;			// buttons
				uint8	start:1;
				uint8	aim_offscreen:1;	// Pretend we're pointing the gun offscreen (ignore the pointer)
			}	justifier;

			struct
			{
				uint8	trigger:1;
			}	macsrifle;

			int32	multi_idx;
			uint16	command;
		}	button;

		union
		{
			struct
			{
				uint8	idx:3;				// Pad number 0-7
				uint8	invert:1;			// 1 = positive is Left/Up/Y/X/L
				uint8	axis:3;				// 0=Left/Right, 1=Up/Down, 2=Y/A, 3=X/B, 4=L/R
				uint8	threshold;			// (threshold+1)/256% deflection is a button press
			}	joypad;

			struct
			{
				uint8	idx:3;				// Pseudo-pointer number 0-7
				uint8	speed_type:2;		// 0=variable, 1=slow, 2=med, 3=fast
				uint8	invert:1;			// 1 = invert axis, so positive is up/left
				uint8	HV:1;				// 0=horizontal, 1=vertical
			}	pointer;

			struct
			{
				uint8	threshold;			// (threshold+1)/256% deflection is a button press
				uint8	negbutton;			// Button ID for negative deflection
				uint8	posbutton;			// Button ID for positive deflection
			}	button;
		}	axis;

		struct								// Which SNES-pointers to control with this pointer
		{
			uint16	aim_mouse0:1;
			uint16	aim_mouse1:1;
			uint16	aim_scope:1;
			uint16	aim_justifier0:1;
			uint16	aim_justifier1:1;
			uint16	aim_macsrifle:1;
		}	pointer;

		uint8	port[4];
	};
}	s9xcommand_t;

// Starting out...

void S9xUnmapAllControls (void);

// Setting which controllers are plugged in.

enum controllers
{
	CTL_NONE,		// all ids ignored
	CTL_JOYPAD,		// use id1 to specify 0-7
	CTL_MOUSE,		// use id1 to specify 0-1
	CTL_SUPERSCOPE,
	CTL_JUSTIFIER,	// use id1: 0=one justifier, 1=two justifiers
	CTL_MP5,			// use id1-id4 to specify pad 0-7 (or -1)
	CTL_MACSRIFLE
};

void S9xSetController (int port, enum controllers controller, int8 id1, int8 id2, int8 id3, int8 id4); // port=0-1
void S9xGetController (int port, enum controllers *controller, int8 *id1, int8 *id2, int8 *id3, int8 *id4);
void S9xReportControllers (void);

// Call this when you're done with S9xSetController, or if you change any of the controller Settings.*Master flags. 
// Returns true if something was disabled.

bool S9xVerifyControllers (void);

// Functions for translation s9xcommand_t's into strings, and vice versa.
// free() the returned string after you're done with it.

char * S9xGetCommandName (s9xcommand_t command);
s9xcommand_t S9xGetCommandT (const char *name);

// Returns an array of strings naming all the snes9x commands.
// Note that this is only the strings for S9xButtonCommand!
// The idea is that this would be used for a pull-down list in a config GUI. DO NOT free() the returned value.

const char ** S9xGetAllSnes9xCommands (void);

// Generic mapping functions

s9xcommand_t S9xGetMapping (uint32 id);
void S9xUnmapID (uint32 id);

// Button mapping functions.
// If a button is mapped with poll=TRUE, then S9xPollButton will be called whenever snes9x feels a need for that mapping.
// Otherwise, snes9x will assume you will call S9xReportButton() whenever the button state changes.
// S9xMapButton() will fail and return FALSE if mapping.type isn't an S9xButton* type.

bool S9xMapButton (uint32 id, s9xcommand_t mapping, bool poll);
void S9xReportButton (uint32 id, bool pressed);

// Pointer mapping functions.
// If a pointer is mapped with poll=TRUE, then S9xPollPointer will be called whenever snes9x feels a need for that mapping.
// Otherwise, snes9x will assume you will call S9xReportPointer() whenever the pointer position changes.
// S9xMapPointer() will fail and return FALSE if mapping.type isn't an S9xPointer* type.

// Note that position [0,0] is considered the upper-left corner of the 'screen',
// and either [255,223] or [255,239] is the lower-right.
// Note that the SNES mouse doesn't aim at a particular point,
// so the SNES's idea of where the mouse pointer is will probably differ from your OS's idea.

bool S9xMapPointer (uint32 id, s9xcommand_t mapping, bool poll);
void S9xReportPointer (uint32 id, int16 x, int16 y);

// Axis mapping functions.
// If an axis is mapped with poll=TRUE, then S9xPollAxis will be called whenever snes9x feels a need for that mapping.
// Otherwise, snes9x will assume you will call S9xReportAxis() whenever the axis deflection changes.
// S9xMapAxis() will fail and return FALSE if mapping.type isn't an S9xAxis* type.

// Note that value is linear -32767 through 32767 with 0 being no deflection.
// If your axis reports differently you should transform the value before passing it to S9xReportAxis().

bool S9xMapAxis (uint32 id, s9xcommand_t mapping, bool poll);
void S9xReportAxis (uint32 id, int16 value);

// Do whatever the s9xcommand_t says to do.
// If cmd.type is a button type, data1 should be TRUE (non-0) or FALSE (0) to indicate whether the 'button' is pressed or released.
// If cmd.type is an axis, data1 holds the deflection value.
// If cmd.type is a pointer, data1 and data2 are the positions of the pointer.

void S9xApplyCommand (s9xcommand_t cmd, int16 data1, int16 data2);

//////////
// These functions are called by snes9x into your port, so each port should implement them.

// If something was mapped with poll=TRUE, these functions will be called when snes9x needs the button/axis/pointer state.
// Fill in the reference options as appropriate.

bool S9xPollButton (uint32 id, bool *pressed);
bool S9xPollPointer (uint32 id, int16 *x, int16 *y);
bool S9xPollAxis (uint32 id, int16 *value);

// These are called when snes9x tries to apply a command with a S9x*Port type.
// data1 and data2 are filled in like S9xApplyCommand.

void S9xHandlePortCommand (s9xcommand_t cmd, int16 data1, int16 data2);

// Called before already-read SNES joypad data is being used by the game if your port defines SNES_JOY_READ_CALLBACKS.

#ifdef SNES_JOY_READ_CALLBACKS
void S9xOnSNESPadRead (void);
#endif

// These are for your use.

s9xcommand_t S9xGetPortCommandT (const char *name);
char * S9xGetPortCommandName (s9xcommand_t command);
void S9xSetupDefaultKeymap (void);
bool8 S9xMapInput (const char *name, s9xcommand_t *cmd);

//////////
// These functions are called from snes9x into this subsystem. No need to use them from a port.

// Use when resetting snes9x.

void S9xControlsReset (void);
void S9xControlsSoftReset (void);

// Use when writing to $4016.

void S9xSetJoypadLatch (bool latch);

// Use when reading $4016/7 (JOYSER0 and JOYSER1).

uint8 S9xReadJOYSERn (int n);

// End-Of-Frame processing. Sets gun latch variables and tries to draw crosshairs

void S9xControlEOF (void);

// Functions and a structure for snapshot.

struct SControlSnapshot
{
	uint8	ver;
	uint8	port1_read_idx[2];
	uint8	dummy1[4];					// for future expansion
	uint8	port2_read_idx[2];
	uint8	dummy2[4];
	uint8	mouse_speed[2];
	uint8	justifier_select;
	uint8	dummy3[8];
	bool8	pad_read, pad_read_last;
	uint8	internal[60];				// yes, we need to save this!
	uint8   internal_macs[5];
};

void S9xControlPreSaveState (struct SControlSnapshot *s);
void S9xControlPostLoadState (struct SControlSnapshot *s);

#endif
