package org.testeditor.tcl.dsl.validation

import java.util.Collection
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameter
import org.junit.runners.Parameterized.Parameters
import org.testeditor.tcl.dsl.tests.validation.AbstractValidationTest

import static org.eclipse.xtext.diagnostics.Severity.*

@RunWith(Parameterized)
class TestEditorUniqueClassNameValidatorTest extends AbstractValidationTest {
	
	// these are names of top-level elements declared in ExampleAmlModel
	@Parameters(name='element name: "{0}", AML type: "{1}"')
	def static Collection<Object[]> exampleAmlElements() {
		return #[
			#['validMonth', 'value space'],
			#['enterMonthAndYear', 'interaction type'],
			#['DateText', 'component element type'],
			#['Dialog', 'component type'],
			#['MyDialog', 'component']
		]
	}
	
	@Parameter(0)
	public String elementName
	
	@Parameter(1)
	public String amlType
	
	private def defaultErrorMessage(String elementName) '''.*The type «elementName» is already defined in.*'''
	private def expectedErrorMessage(String elementName, String amlType, String tclType) '''.*There is already a\(n\) «amlType» named '«elementName»' in this package defined in __synthetic0\.aml\. Rename either this «tclType» or the «amlType», or move either one to a different package\..*'''

	@Test
	def void testThatUserFriendlyMessageIsReportedForNamingConflictBetweenTestCasesAndAmlElements() {
		// given
		val tclModel = '''
			package com.example
			
			# «elementName»
			* Sample Step
		'''.toString.parseTcl('''«elementName».tcl''')

		// when
		val validations = validator.validate(tclModel)

		// then
		validations.assertNotExists([message.matches(defaultErrorMessage(elementName).toString) && severity == ERROR], tclModel.reportableValidations)
		validations.assertExists([message.matches(expectedErrorMessage(elementName, amlType, 'test case').toString) && severity == ERROR], tclModel.reportableValidations)
	}
	
	@Test
	def void testThatUserFriendlyMessageIsReportedForNamingConflictBetweenTestframesAndAmlElements() {
		// given
		val tclModel = '''
			package com.example
			
			config «elementName»
		'''.toString.parseTcl('''«elementName».tfr''')

		// when
		val validations = validator.validate(tclModel)

		// then
		validations.assertNotExists([message.matches(defaultErrorMessage(elementName).toString) && severity == ERROR], tclModel.reportableValidations)
		validations.assertExists([message.matches(expectedErrorMessage(elementName, amlType, 'test frame').toString) && severity == ERROR], tclModel.reportableValidations)
	}
	
}