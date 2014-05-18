#!/bin/bash

cd "$(dirname "$0")/../../.."

function gen-qc {
	cat <<EOF

//
//	AUTOGENERATED FILE, DO NOT MODIFY
//	DO NOT LOOK, EITHER
//

#define COMPATVAR_ACTIVE(v) ((cvar_type(v) & CVAR_TYPEFLAG_EXISTS) && cvar_string(v) != "__COMPATVAR_DISABLED__")

void RM_CvarCompat() {
	float corrections;
	float mode = cvar("sv_rm_cvarcompat");
	
	if(!mode)
		return;
	
	print("Checking config compatibility...\n");
	
$(cat cvars.compat | while read line; do
	old=${line%% *}
	new=${line##* }
	
cat <<EOB
	// $old ---> $new
	
	if COMPATVAR_ACTIVE("$old") {
		print("^1WARNING: ^7Your configuration uses an OUTDATED cvar name: ^3$old^7. Will _TRY_ to stay compatible by updating ^3$new^7, but no stability is guaranteed at this point!\n");
		cvar_set("$new", cvar_string("$old"));
		if(mode == 2)
			cvar_set("$old", "__COMPATVAR_DISABLED__");
		++corrections;
	}
	
EOB
done)

	if(corrections)
		print("\n^1***\nPlease update your server configuration using the update-cvars.sh script.\nYou can find it in the RM git repository.\nNOTE: If you run RM in 'singleplayer' mode, you will also have to update your config.cfg.\n^1***\n\n");
	else
		print("Fully compatible, NICE\n");
	
	if(cvar("sv_rm_cvarcompat_autodisable") && (!corrections || mode == 2)) {
		cvar_set("sv_rm_cvarcompat", "0");
		print("sv_rm_cvarcompat is now DISABLED\n");
	}
}

#undef COMPATVAR_ACTIVE

EOF
}

function gen-cfg {
	cat <<EOF

//
//	AUTOGENERATED FILE, DO NOT MODIFY
//	DO NOT LOOK, EITHER
//

EOF
	
	cat cvars.compat | while read line; do
		old=${line%% *}
		new=${line##* }
		echo "set $old __COMPATVAR_DISABLED__ \"Compatbility cvar: DO NOT USE. Use $new instead.\""
	done
}

gen-qc  > qcsrc/server/rm_cvarcompat.qc
gen-cfg > rocketminsta-compat.cfg