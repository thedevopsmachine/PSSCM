Import-Module Pester
Import-Module C:\Users\justin.yancey\Documents\PSSCM\PSSCM\Modules\PSSCM.psd1

Describe "ConvertTo-Dictionary" {
	It "ConvertAnObjectToAHashtable" {
		$o = New-Object PSObject -Property @{Name = "Justin"; Surname = "Yancey"}
		$ht = ConvertTo-Dictionary -Object $o
		$ht.GetType().Name | Should Be "Hashtable"
		$ht["Name"] | Should Be "Justin"
		$ht["Surname"] | Should Be "Yancey"
	}
}