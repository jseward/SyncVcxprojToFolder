param(
	[string]$project,
	[string]$folder
)

function Get-RelativePath ($full_file_path, $relative_to_file_path) {

	#http://stackoverflow.com/questions/10972589/get-relative-path-of-files-in-sub-folders-from-the-current-directory
	#http://stackoverflow.com/questions/9063964/folder-path-of-powershell-file-in-powershell
	
	$relative = $null
	
	$relative_to_dir = Split-Path -parent $relative_to_file_path
	$old_location = Get-Location
	try {
		Set-Location $relative_to_dir
		$relative = (Get-Item $full_file_path | Resolve-Path -relative)
	}
	finally {
		Set-Location $old_location	
	}

	return $relative
}

function Update-vcxproj ($project_path, $files) {

	#http://stackoverflow.com/questions/11556987/parsing-vcxproj-with-system-xml-xmldocument
	$xmldoc = New-Object System.Xml.XmlDocument
	$xmldoc.Load($project_path)
	$ns = "http://schemas.microsoft.com/developer/msbuild/2003"
	$nsmgr = New-Object System.Xml.XmlNamespaceManager($xmldoc.NameTable);
	$nsmgr.AddNamespace("rs", $ns);

	$root = $xmldoc.DocumentElement
	#skip the first ItemGroup node with Label attribute, that is collection of ProjectConfiguration nodes
	$item_group_node = $root.SelectSingleNode("/rs:Project/rs:ItemGroup[not(@Label)]", $nsmgr)
	$item_group_node.RemoveAll()
		
	foreach ($file in $files) {
		$child = $xmldoc.CreateElement("None", $ns)
		$child.SetAttribute("Include", (Get-RelativePath $file.FullName $project_path))
		$item_group_node.AppendChild($child) | Out-Null
	}
		
	$xmldoc.Save($project_path)
}

function Update-vcxproj-filters ($project_filters_path, $files, $folder_relative_path) {

	#http://stackoverflow.com/questions/11556987/parsing-vcxproj-with-system-xml-xmldocument
	$xmldoc = New-Object System.Xml.XmlDocument
	$xmldoc.Load($project_filters_path)
	$ns = "http://schemas.microsoft.com/developer/msbuild/2003"
	$nsmgr = New-Object System.Xml.XmlNamespaceManager($xmldoc.NameTable);
	$nsmgr.AddNamespace("rs", $ns);

	$root = $xmldoc.DocumentElement
	$filter_item_group = $root.SelectSingleNode("/rs:Project/rs:ItemGroup[rs:Filter]", $nsmgr)
	if (!$filter_item_group) {
		$filter_item_group = $xmldoc.CreateElement("ItemGroup", $ns)
		$root.AppendChild($filter_item_group) | Out-Null
	}
	
	#want to preserve old filters as they have a unique guid we don't want to change every time this script is run.
	$old_filters = @{}
	foreach ($filter_item in $filter_item_group.ChildNodes) {
		#TOFIX: $filter_item.SelectSingleNode("//rs:UniqueIdentifier", $nsmgr).InnerText doesn't seem to work properly, so manually using ChildNodes[0]
		#$guid = $filter_item.SelectSingleNode("//rs:UniqueIdentifier", $nsmgr).InnerText
		$guid = $filter_item.ChildNodes[0].InnerText
		$old_filters.Add($filter_item.GetAttribute("Include"), $guid)
	}
	
	$file_item_group = $root.SelectSingleNode("/rs:Project/rs:ItemGroup[rs:None]", $nsmgr)
	if (!$file_item_group) {
		$file_item_group = $xmldoc.CreateElement("ItemGroup", $ns)
		$root.AppendChild($file_item_group) | Out-Null
	}
	$file_item_group.RemoveAll()
	
	$file_filters = @{}
	foreach ($file in $files) {
		$file_relative_path = [string](Get-RelativePath $file.FullName $project_filters_path)
		if (!$file_relative_path.StartsWith($folder_relative_path)) {			
			throw "Expected $file_relative_path to start with $folder_relative_path"
		}
		$file_bare_path = $file_relative_path.SubString($folder_relative_path.Length + 1)
		$file_filter = Split-Path -Path $file_bare_path -Parent
	
		$child = $xmldoc.CreateElement("None", $ns)
		$child.SetAttribute("Include", $file_relative_path)
		
		$child_filter = $xmldoc.CreateElement("Filter", $ns)
		$child_filter.InnerText = $file_filter
		$child.AppendChild($child_filter) | Out-Null
		
		$file_item_group.AppendChild($child) | Out-Null
		
		if (!$file_filters.ContainsKey($file_filter)) {
			$file_filters.Add($file_filter, "")
		}
	}
	
	#add missing filters
	foreach ($file_filter in $file_filters.GetEnumerator()) {
		if (!$old_filters.ContainsKey($file_filter.Key)) {
			$uuid_node = $xmldoc.CreateElement("UniqueIdentifier", $ns)
			$uuid_node.InnerText = "{" + [guid]::NewGuid() + "}"
			$new_filter_node = $xmldoc.CreateElement("Filter", $ns)
			$new_filter_node.SetAttribute("Include", $file_filter.Key)
			$new_filter_node.AppendChild($uuid_node) | Out-Null
			$filter_item_group.AppendChild($new_filter_node) | Out-Null
		}
	}
	
	$xmldoc.Save([string]$project_filters_path)
}


$ErrorActionPreference = "Stop"

$project_path = Resolve-Path $project
$project_filters_path = Resolve-Path ("$project" + ".filters")
$folder_path = Resolve-Path $folder
$folder_files = Get-ChildItem -path $folder_path -file -recurse
$folder_relative_path = Get-RelativePath $folder_path $project_path

Update-vcxproj $project_path $folder_files
Update-vcxproj-filters $project_filters_path $folder_files $folder_relative_path
