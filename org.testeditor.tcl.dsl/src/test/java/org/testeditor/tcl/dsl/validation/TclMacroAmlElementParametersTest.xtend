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
		parseAml(DummyFixture.amlModel)
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
	def void testAmlElementParameterRequiresStringType() {
		// given
		val tmlModel = '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "indirectly type" ${value} "into" ${field}
			Component: GreetingApplication
			 -  TypeLong @value into <@field>
		'''.toString.parseTcl("MyMacroCollection.tml")
			
		tmlModel.assertNoErrors

		val tclModel = '''
			package com.example
			
			# SampleTest
			* Sample Step
			Component: GreetingApplication
			- myElementVar = Read long from <Input>
			Macro: MyMacroCollection
			- indirectly type "42" into @myElementVar
		'''.toString.parseTcl("SampleTest.tcl")

		// when
		val validations = validator.validate(tclModel)

		// then
		validations.assertNotEmpty
	}
	
}