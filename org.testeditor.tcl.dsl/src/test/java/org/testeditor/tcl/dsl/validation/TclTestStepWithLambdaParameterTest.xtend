package org.testeditor.tcl.dsl.validation

import javax.inject.Inject
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Before
import org.junit.Test
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.tcl.dsl.tests.parser.AbstractParserTest

class TclTestStepWithLambdaParameterTest extends AbstractParserTest {

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
	def void testLambdaParameter() {
		// given
		DummyFixture.parameterizedTestAml.parseAml.assertNoSyntaxErrors
		'''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "enter" ${value} "into" ${field}
			Component: GreetingApplication
			- Type @value into <@field>
		'''.toString.parseTcl('MyMacroCollection.tml').assertNoSyntaxErrors
		
		val tclModel = '''
			package com.example
			
			# SampleTest
			* Some test specification step
			  Component: ParameterizedTesting
			  - inputs = load inputs from "path/to/file.json"
			  - entry = each entry in @inputs:
			    Macro: MyMacroCollection
			    -- enter @entry into "Input"
			    -- enter @entry into "Input"
		'''.toString.parseTcl('SampleTest.tcl').assertNoSyntaxErrors
		
		// when
		val validations = validator.validate(tclModel)
		
		// then
		validations.assertEmpty
	}
	
}
