/*******************************************************************************
 * Copyright (c) 2012 - 2018 Signal Iduna Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Contributors:
 * Signal Iduna Corporation - initial API and implementation
 * akquinet AG
 * itemis AG
 *******************************************************************************/
package org.testeditor.tcl.dsl.validation

import org.eclipse.xtext.validation.Issue
import org.eclipse.xtext.xbase.lib.Functions.Function1
import org.junit.Test
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.tcl.dsl.tests.validation.AbstractValidationTest

import static org.eclipse.xtext.diagnostics.Severity.*

class TclValidatorTest extends AbstractValidationTest {

	@Test
	def void validateStringArray() {
		// given
		val Function1<Issue, Boolean> warningPredicate = [
			message.matches(".*Allowed values: '\\[New, Open\\]'.*") && severity == WARNING
		]
		getAMLWithValueSpace('''#[ "New", "Open" ]''').parseAml

		var tcl = getTCLWithValue("Test", "New")
		var tclExpectingWarning = getTCLWithValue("Test2", "Save")

		// when
		var model = parseTcl(tcl.toString, "Test.tcl")
		var modelExpectingWarning = parseTcl(tclExpectingWarning.toString, "Test2.tcl")

		// then
		validator.validate(model).assertNotExists(warningPredicate, model.reportableValidations)
		validator.validate(modelExpectingWarning).assertExists(warningPredicate, modelExpectingWarning.reportableValidations)
	}

	@Test
	def void validateNumberRange() {
		// given
		val Function1<Issue, Boolean> warningPredicate = [
			message.matches(".*Allowed values: '2 <= x <= 5'.*") && severity == WARNING
		]
		getAMLWithValueSpace("2 ... 5").parseAml

		var tcl = getTCLWithValue("Test", "4")
		var tclExpectingWarning = getTCLWithValue("Test2", "1")

		// when
		var model = parseTcl(tcl.toString, "Test.tcl")
		var modelExpectingWarning = parseTcl(tclExpectingWarning.toString, "Test2.tcl")

		// then
		validator.validate(model).assertNotExists(warningPredicate, model.reportableValidations)
		validator.validate(modelExpectingWarning).assertExists(warningPredicate, modelExpectingWarning.reportableValidations)
	}

	@Test
	def void validateRegEx() {
		// given
		val Function1<Issue, Boolean> warningPredicate = [
			message.matches(".*Allowed values: 'Regular expression: \\^\\[a-zA-Z_0-9\\]'.*") && severity == WARNING
		]
		getAMLWithValueSpace('''"^[a-zA-Z_0-9]"''').parseAml

		var tcl = getTCLWithValue("Test", "h")
		var tclExpectingWarning = getTCLWithValue("Test2", "!!hello")

		// when
		var model = parseTcl(tcl.toString, "Test.tcl")
		var modelExpectingWarning = parseTcl(tclExpectingWarning.toString, "Test2.tcl")

		// then
		validator.validate(model).assertNotExists(warningPredicate, model.reportableValidations)
		validator.validate(modelExpectingWarning).assertExists(warningPredicate, modelExpectingWarning.reportableValidations)
	}

	@Test
	def void testValidateFieldsWithManyValueSpaces() {
		// given
		val Function1<Issue, Boolean> warningPredicate = [
			message.matches(".*Allowed values: '\\[foo, bar\\]'.*") && severity == WARNING
		]
		getAMLWithValueSpace('''#["foo", "bar"]''').parseAml

		var tcl = getTCLWithTwoValueSpaces("Test", "foo", "Mask")
		var tclExpectingWarning = getTCLWithTwoValueSpaces("Test2", "fooHello", "Mask")

		// when
		var model = parseTcl(tcl.toString, "Test.tcl")
		var modelExpectingWarning = parseTcl(tclExpectingWarning.toString, "Test2.tcl")

		// then
		validator.validate(model).assertNotExists(warningPredicate, model.reportableValidations)
		validator.validate(modelExpectingWarning).assertExists(warningPredicate, modelExpectingWarning.reportableValidations)
	}
	
	@Test
	def void testValidateMacroReturnCorrectUsage() {
		// given
		val Function1<Issue, Boolean> errorPredicate = [
			message.matches(".*'return' is only allowed as last step of a macro definition.*") && severity == ERROR
		]

		val model = '''
			package org.testeditor
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "return variable with keyword"
			Component: AComponent
			- return 42
		'''.toString.parseTcl("MyMacroCollection.tml")

		// when
		val validations = validator.validate(model)

		// then
		validations.assertNotExists(errorPredicate, model.reportableValidations)
	}
	
	@Test
	def void testValidateMacroReturnNotLastStep() {
		// given
		val Function1<Issue, Boolean> errorPredicate = [
			message.matches(".*'return' is only allowed as last step of a macro definition.*") && severity == ERROR
		]

		val model = '''
			package org.testeditor
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "return variable with keyword"
			Component: AComponent
			- return 42
			- some other step
		'''.toString.parseTcl("MyMacroCollection.tml")

		// when
		val validations = validator.validate(model)

		// then
		validations.assertExists(errorPredicate, model.reportableValidations)
		validations.findFirst(errorPredicate) => [
			lineNumber.assertEquals(8)
			uriToProblem.fragment.assertEquals('/0/@macroCollection/@macros.0/@contexts.0/@steps.0')
		]
	}
	
	@Test
	def void testValidateMacroReturnNotLastContext() {
		// given
		val Function1<Issue, Boolean> errorPredicate = [
			message.matches(".*'return' is only allowed as last step of a macro definition.*") && severity == ERROR
		]

		val model = '''
			package org.testeditor
			
			# MyMacroCollection
			
			## MacroWithReturn
			template = "return variable with keyword"
			Component: AComponent
			- return 42
			Component: AnotherComponent
			- some other step
		'''.toString.parseTcl("MyMacroCollection.tml")

		// when
		val validations = validator.validate(model)

		// then
		validations.assertExists(errorPredicate, model.reportableValidations)
		validations.findFirst(errorPredicate) => [
			lineNumber.assertEquals(8)
			uriToProblem.fragment.assertEquals('/0/@macroCollection/@macros.0/@contexts.0/@steps.0')
		]
	}
	
	@Test
	def void testValidateMacroReturnNotInsideMacroDefinition() {
		// given
		val Function1<Issue, Boolean> errorPredicate = [
			message.matches(".*'return' is only allowed as last step of a macro definition.*") && severity == ERROR
		]

		val model = '''
			package com.example
			
			# SampleTest
			* Sample Step
			Component: AComponent
			- return 42
		'''.toString.parseTcl("SampleTest.tcl")

		// when
		val validations = validator.validate(model)

		// then
		validations.assertExists(errorPredicate, model.reportableValidations)
		validations.findFirst(errorPredicate) => [
			lineNumber.assertEquals(6)
			uriToProblem.fragment.assertEquals('/0/@test/@steps.0/@contexts.0/@steps.0')
		]
	}

	@Test
	def void testValidateMacroWithoutReturnAssignedToVariable() {
		// given
		val Function1<Issue, Boolean> errorPredicate = [
			message.matches(".*macro cannot be assigned to 'value' since it does not return anything.*") && severity == ERROR
		]
		
		val tmlModel = '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "my macro"
			Component: com.example.MyDialog
			 - Enter month "10" and year "2000" into <Date>
		'''.toString.parseTcl("MyMacroCollection.tml")
			
		tmlModel.assertNoErrors

		val tclModel = '''
			package com.example
			
			# SampleTest
			* Sample Step
			Macro: MyMacroCollection
			- value = my macro
		'''.toString.parseTcl("SampleTest.tcl")

		// when
		val validations = validator.validate(tclModel)

		// then
		validations.assertExists(errorPredicate, tclModel.reportableValidations)
		validations.findFirst(errorPredicate) => [
			lineNumber.assertEquals(6)
			uriToProblem.fragment.assertEquals('/0/@test/@steps.0/@contexts.0/@steps.0')
		]
	}
	
	@Test
	def void testReferencesComponentElementIgnoresMacroCalls() {
		// given
		val tmlModel = '''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "indirectly enter month" ${m} "and year" ${y} "into" ${field}
			Component: com.example.MyDialog
			 - Enter month @m and year @y into <@field>
		'''.toString.parseTcl("MyMacroCollection.tml")
			
		tmlModel.assertNoErrors

		val tclModel = '''
			package com.example
			
			# SampleTest
			* Sample Step
			Macro: MyMacroCollection
			- indirectly enter month "10" and year "2000" into "Date"
		'''.toString.parseTcl("SampleTest.tcl")

		// when
		val validations = validator.validate(tclModel)

		// then
		validations.assertNotExists([message.matches(".*No ComponentElement found.*") && severity == ERROR], tclModel.reportableValidations)
		validations.assertNotExists([message.matches(".*test step could not resolve macro usage.*") && severity == WARNING], tclModel.reportableValidations)
	}
	
	@Test
	def void testCanDereferenceTestParameter() {
		// given
		DummyFixture.amlModel.parseAml
		DummyFixture.parameterizedTestAml.parseAml

		val tclModel = '''
			package com.example
			
			# SampleTest
			
			Data:
				Component: ParameterizedTesting
				- parameters = load data from "testData"
			
			* test something
			Component: GreetingApplication
			- Type @parameters.firstName into <Input>

		'''.toString.parseTcl("SampleTest.tcl")

		// when
		val validations = validator.validate(tclModel)

		// then
		validations.assertNotExists([message.matches(".*Dereferenced variable must be a required environment variable or a previously assigned variable.*")
			&& severity == ERROR], tclModel.reportableValidations)
	}

	def getTCLWithTwoValueSpaces(String testName, String value1, String value2) {
		getTCLWithValue(testName, value1) + '''
			- execute menu item  "«value2»"  in tree <TestStepSelector>
		'''
	}

	def CharSequence getTCLWithValue(String testName, String value) {
		'''
			package com.example
			
			# «testName»
			* Start the famous greetings application
			Component: ProjectExplorer
			- execute menu item  "«value»"  in tree <ProjektBaum>
		'''
	}

	def CharSequence getAMLWithValueSpace(String valuespace) {
		'''
			package com.example
			
			interaction type executeContextMenuEntry {
				label = " execute context menu entry"
				template = "execute menu item " ${item} " in tree" ${element} 
				method = AnyFixture.executeContextMenuEntry(element,item)
			}
			
			element type TreeView {
				interactions =  executeContextMenuEntry
			}
			
			value-space projectmenues = «valuespace» 
			value-space components = #["Mask", "Component"] 
			
			component type General {
			}
			
			
			component ProjectExplorer is General {
				element ProjektBaum is TreeView {
					label = "Projekt Baum"
					locator ="Project Explorer"
					executeContextMenuEntry.item restrict to projectmenues 
				}
				element TestStepSelector is TreeView {
					label = "Teststep selector"
					locator ="teststepSelector"
					executeContextMenuEntry.item restrict to components 
				}
			}
		'''
	}
}
