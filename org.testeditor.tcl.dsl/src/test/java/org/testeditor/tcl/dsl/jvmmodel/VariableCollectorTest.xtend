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
package org.testeditor.tcl.dsl.jvmmodel

import com.google.gson.JsonObject
import javax.inject.Inject
import org.eclipse.xtext.EcoreUtil2
import org.junit.Before
import org.junit.Test
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.fixture.core.MaskingString
import org.testeditor.tcl.TestStepContext
import org.testeditor.tcl.dsl.tests.parser.AbstractParserTest

class VariableCollectorTest extends AbstractParserTest {
	static val macroCollectionName = 'MyMacroCollection'

	@Inject VariableCollector variableCollector // class under test

	@Before
	def void setup() {
		DummyFixture.amlModel.parseAml
		'''
				«DummyFixture.getMacroModel(macroCollectionName)»
				
				## ReturnLongFromInteraction
				template = "get long"
				Component: GreetingApplication
				- result = Read long from <Input>
				- return result
				
				## ReturnLongFromMacro
				template = "get long indirectly"
				Macro: «macroCollectionName»
				- result = get long
				- return result
		'''.toString
		.parseTcl(macroCollectionName + '.tml')
	}

	@Test
	def void testCollectDeclaredVariablesTypeMap() {
		// given
		val tcl = '''
			package com.example
			
			# MyTest
			
			* do some
				Component: GreetingApplication
				- longVar = Read long from <bar>
				- boolVar = Read bool from <bar>
				- jsonVar = Read jsonObject from <bar>
				- Is <bar> visible?                 // no assignment test step
				- Read value from <bar>             // no assignment of value
				- stringVar = Read value from <bar>
				- confidentialVar = Read confidential information from <bar>

				Macro: «macroCollectionName»
				- longFromMacro = get long // call a macro that calls a fixture
				- longFromMacroIndirectly = get long indirectly // call a macro that calls another macro that calls a fixture
		'''
		val tclModel = tcl.parseTcl('MyTest.tcl')
		tclModel.assertNoErrors

		// when
		val componentContext = EcoreUtil2.getAllContentsOfType(tclModel, TestStepContext).head
		val macroContext = EcoreUtil2.getAllContentsOfType(tclModel, TestStepContext).last
		val declaredVariables = newHashMap
		declaredVariables += variableCollector.collectDeclaredVariablesTypeMap(componentContext)
		declaredVariables += variableCollector.collectDeclaredVariablesTypeMap(macroContext)

		// then
		declaredVariables.keySet.assertSize(7)
		declaredVariables.get("longVar").qualifiedName.assertEquals(long.name)
		declaredVariables.get("boolVar").qualifiedName.assertEquals(boolean.name)
		declaredVariables.get("jsonVar").qualifiedName.assertEquals(JsonObject.name)
		declaredVariables.get("stringVar").qualifiedName.assertEquals(String.name)
		declaredVariables.get("confidentialVar").qualifiedName.assertEquals(MaskingString.name)

		declaredVariables.get("longFromMacro").qualifiedName.assertEquals(long.name)
		declaredVariables.get("longFromMacroIndirectly").qualifiedName.assertEquals(long.name)
	}

}
