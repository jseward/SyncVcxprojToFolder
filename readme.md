What does this script do?
---

During game development it is super handy to have all data files in Visual Studio's solution explorer. Any navigation and search tools can then work with data along with code. 
The problem is keeping a project file in sync with all of these data files. This script will automate the updating of .vcxproj and vcxproj.filters files. The directory structure
will be represented with visual studio "filters" (fancy name for folders for our purposes).

To Use
---
1. create an empty visual c++ project file
2. run this script
3. repeat whenever data files are added / removed or as desired
4. ...
5. profit

example folder structure

	\mygame
		\data
			\fonts
				xxx.font
			\textures
				yyy.tga
		\msvc
			mygame_data.vcxproj
			mygame_data.vcxproj.filters

command line

	.\SyncVcxprojToFolder.ps1 -project "c:\mygame\msvc\mygame_data.vcxproj" -folder "c:\mygame\data"

