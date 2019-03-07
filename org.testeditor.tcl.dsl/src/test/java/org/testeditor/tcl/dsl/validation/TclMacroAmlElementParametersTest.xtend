package org.testeditor.tcl.dsl.validation

import javax.inject.Inject
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Before
import org.junit.Test
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.tcl.dsl.tests.parser.AbstractParserTest

import static org.eclipse.xtext.diagnostics.Severity.ERROR

class TclMacroAmlElementParametersTest extends AbstractParserTest {

	@Inject
	ValidationTestHelper validator

	@Before
	def void setup() {
		parseAml(DummyFixture.amlModel + '''
		
		interaction type noValidElement {
			template = "This interaction is not valid on" ${element} "or any other element"
			method = «DummyFixture.simpleName».getValue(element)
		}''')
	}
	
	@Test
	def void testValidateAmlElementParameterType() {
		
		// given
		'''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "send greetings to" ${field}
			Component: GreetingApplication
			- Type "Hello, World!" into <@field>
		'''.toString.parseTcl("MyMacroCollection.tml").assertNoErrors
		val tclModel = '''
			package com.example
			
			# SampleTest
			* Sample Step
			Macro: MyMacroCollection
			- send greetings to "NonExistingElement"
		'''.toString.parseTcl("SampleTest.tcl")
		
		// when
		val validations = validator.validate(tclModel)
		
		// then
		validations.assertSingleElement => [
			message.assertMatches('.*"NonExistingElement" does not match any of the allowed elements \\("Input"\\)\\..*')
			severity.assertEquals(ERROR)
			]
	}
	
	@Test
	def void testValidateAmlElementParameterConsistency() {
		
		// given
		val tmlModel = '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "send greetings to" ${field}
			Component: GreetingApplication
			- Type "Hello, World!" into <@field>
			- Click on <@field>
		'''.toString.parseTcl("MyMacroCollection.tml")
		
		// when
		val validations = validator.validate(tmlModel)
		
		// then
		val inconsistencyErrors = validations.filter[message.startsWith('variable "field" is used inconsistently.') && severity.equals(ERROR)]
		inconsistencyErrors.assertSize(2)
	}
	
	@Test
	def void testNoConsistencyCheckOnSingleUsageWithoutValidElements() {
		
		// given
		val tmlModel = '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "send greetings to" ${field}
			Component: GreetingApplication
			- This interaction is not valid on <@field> or any other element
		'''.toString.parseTcl("MyMacroCollection.tml")
		
		// when
		val validations = validator.validate(tmlModel)
		
		// then
		validations.assertNotExists[message.startsWith('variable "field" is used inconsistently.') && severity.equals(ERROR)]
	}
	
}