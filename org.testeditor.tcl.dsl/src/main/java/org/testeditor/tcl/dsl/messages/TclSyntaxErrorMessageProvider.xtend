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
package org.testeditor.tcl.dsl.messages

import org.antlr.runtime.MismatchedTokenException
import org.antlr.runtime.MissingTokenException
import org.antlr.runtime.NoViableAltException
import org.antlr.runtime.RecognitionException
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.nodemodel.SyntaxErrorMessage
import org.eclipse.xtext.parser.antlr.SyntaxErrorMessageProvider
import org.eclipse.xtext.xbase.lib.Functions.Function1
import org.testeditor.tcl.TclModel
import org.testeditor.tcl.TestData

class TclSyntaxErrorMessageProvider extends SyntaxErrorMessageProvider {

	public static val String MISSING_TEST_DESCRIPTION = "missingTestDescription"
	public static val String MULTIPLE_DATA_CONTEXTS = "multipleDataContexts"
	public static val String MULTIPLE_DATA_STEPS = "multipleDataSteps"
	public static val String NO_ASSIGNMENT_IN_DATA_BLOCK = "noAssignmentInDataBlock"
	public static val String NO_DATA_CONTEXT = "noDataContext"
	public static val String MACRO_CONTEXT_IN_DATA_BLOCK = "macroContextInDataBlock"
	
	public static val int EOF = -1
	
	static val MISSING_TEST_DESCRIPTION_MSG = new SyntaxErrorMessage('''
		Insert a test description before the actual test context.
		E.g. "* This test will check that the answer will be 42"
	''', MISSING_TEST_DESCRIPTION)

	static val MULTIPLE_DATA_CONTEXTS_MSG = new SyntaxErrorMessage(
		'The data block cannot have more than one test step context.', 
		MULTIPLE_DATA_CONTEXTS)

	static val MULTIPLE_DATA_STEPS_MSG = new SyntaxErrorMessage(
		'The data block cannot have more than one test step.', 
		MULTIPLE_DATA_STEPS)

	static val NO_DATA_CONTEXT_MSG = new SyntaxErrorMessage('''
			The data block must have a component test step context.
			E.g. add "Component: MyComponent" after the data block line.
		''', NO_DATA_CONTEXT)

	static val MACRO_CONTEXT_IN_DATA_BLOCK_MSG = new SyntaxErrorMessage('''
			The data block cannot have a macro test step context.
			E.g. replace the macro context with a component context like "Component: MyComponent".''', 
			MACRO_CONTEXT_IN_DATA_BLOCK)

	static val NO_ASSIGNMENT_IN_DATA_BLOCK_MSG = new SyntaxErrorMessage('''
		The data initialization step must be an assignment.
		E.g. prefix the step with "- myVar = ".''',
		NO_ASSIGNMENT_IN_DATA_BLOCK)


	override getSyntaxErrorMessage(IParserErrorContext it) {
		return switch (exception : recognitionException) {
			NoViableAltException case currentContext.isTestModelWithoutTestStepsYet:
				MISSING_TEST_DESCRIPTION_MSG
			MissingTokenException case currentContext.isTestModelWithDataBlock && exception.expecting === EOF:
				switch (token : exception.token.text) {
					case token.startsTestStepContext:
						MULTIPLE_DATA_CONTEXTS_MSG
					case token.startsTestStep:
						MULTIPLE_DATA_STEPS_MSG
				}
			MissingTokenException case tokenName(exception.expecting) == "'='": 
				NO_ASSIGNMENT_IN_DATA_BLOCK_MSG
			MismatchedTokenException case currentContext instanceof TestData && tokenName(exception.expecting) == "'Component'":
				switch (token : exception.token.text) {
					case 'Macro' == token:
						MACRO_CONTEXT_IN_DATA_BLOCK_MSG
					default:
						NO_DATA_CONTEXT_MSG
				}
			default: super.getSyntaxErrorMessage(it)	
		}
	}
	
	private def startsTestStep(String token) {
		return token == '-'
	}
	
	private def startsTestStepContext(String token) {
		return token == 'Component' || token == 'Mask' || token == 'Macro'
	}
	
	private def String tokenName(IParserErrorContext it, int tokenID) {
		return if (tokenID < 0 || tokenID >= tokenNames.size) {
			'EOF'
		} else {
			tokenNames.get(tokenID)
		}
	}

	/**
	 * exception is a MismatchedTokenException raised because EOF is expected
	 */
	private def boolean isMismatchedTokenExceptionExpectingEOF(RecognitionException exception) {
		return (exception instanceof MismatchedTokenException) &&
			(exception as MismatchedTokenException).expecting == -1
	}
	
	private def boolean isMissingTokenExceptionExpectingEOF(RecognitionException exception) {
		return (exception instanceof MissingTokenException) &&
			(exception as MissingTokenException).expecting === -1
	}

	private def boolean isMissingToken(RecognitionException exception, int tokenId) {
		return (exception instanceof MissingTokenException) &&
			(exception as MissingTokenException).expecting === -1
	}
	/**
	 * context is a TclModel which has no steps defined yet
	 */
	private def boolean isTestModelWithoutTestStepsYet(EObject context) {
		return if (context instanceof TclModel) {
			context?.test?.steps.nullOrEmpty
		} else { 
			false
		}
	}
	
	private def boolean isTestModelWithDataBlock(EObject context) {
		return if (context instanceof TclModel) {
			context?.test.check[
				setup.nullOrEmpty &&
				cleanup.nullOrEmpty &&
				steps.nullOrEmpty &&
				!data.nullOrEmpty &&
				data.head.context !== null
			]
		} else { 
			false
		}
	}
	
	private def <T> boolean check(T element, Function1<T, Boolean> checkFunction) {
		return element !== null && checkFunction.apply(element)
	}
}
