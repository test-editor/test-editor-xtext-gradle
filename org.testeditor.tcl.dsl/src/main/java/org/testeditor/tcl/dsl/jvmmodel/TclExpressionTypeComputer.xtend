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

import java.text.NumberFormat
import java.text.ParseException
import java.util.Map
import java.util.Optional
import java.util.regex.Pattern
import javax.inject.Inject
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.common.types.JvmTypeReference
import org.testeditor.aml.TemplateContainer
import org.testeditor.aml.TemplateVariable
import org.testeditor.aml.Variable
import org.testeditor.dsl.common.util.JvmTypeReferenceUtil
import org.testeditor.fixture.core.MaskingString
import org.testeditor.tcl.AssignmentVariable
import org.testeditor.tcl.ComparatorEquals
import org.testeditor.tcl.ComparatorGreaterThan
import org.testeditor.tcl.ComparatorLessThan
import org.testeditor.tcl.ComparatorMatches
import org.testeditor.tcl.Comparison
import org.testeditor.tcl.EnvironmentVariable
import org.testeditor.tcl.Expression
import org.testeditor.tcl.JsonArray
import org.testeditor.tcl.JsonBoolean
import org.testeditor.tcl.JsonNull
import org.testeditor.tcl.JsonNumber
import org.testeditor.tcl.JsonObject
import org.testeditor.tcl.JsonString
import org.testeditor.tcl.JsonValue
import org.testeditor.tcl.NullOrBoolCheck
import org.testeditor.tcl.StepContentElement
import org.testeditor.tcl.TestParameter
import org.testeditor.tcl.VariableReference
import org.testeditor.tcl.VariableReferencePathAccess
import org.testeditor.tsl.StepContent
import org.testeditor.tsl.StepContentVariable

/**
 * compute the resulting type (as JvmTypeReference) of tcl expressions as they would be/are generated
 */
class TclExpressionTypeComputer {
	
	@Inject SimpleTypeComputer typeComputer
	@Inject TclJsonUtil jsonUtil
	@Inject JvmTypeReferenceUtil typeReferenceUtil
	@Inject TclCoercionComputer coercionComputer
	
	def boolean isJsonType(Expression expression) {
		switch expression {
			JsonValue: return true // supertype of all (relevant) json types (e.g. JsonObject, JsonArray, JsonString ...)
			VariableReferencePathAccess: return true // since this is only allowed for json types, the result is a json type, too
			VariableReference: return jsonUtil.isJsonType(determineType(expression, Optional.empty))
			default: return false
		}
	}
	
	def dispatch JvmTypeReference determineType(StepContent stepContent, Optional<JvmTypeReference> expectedType) {
		typeReferenceUtil.initWith(stepContent.eResource)
		val nonFractionalNumberPattern = Pattern.compile("(\\+|\\-)?[0-9]+")
		val fractionalNumberPattern = Pattern.compile("(\\+|\\-)?[0-9]+(\\.[0-9]+)?")
		val booleanPattern = Pattern.compile("true|false", Pattern.CASE_INSENSITIVE)
		switch stepContent {
			StepContentVariable, StepContentElement: {
				if((expectedType?:Optional.empty).present) {
					if (typeReferenceUtil.isString(expectedType.get)) {
						return expectedType.get
					}
					if (typeReferenceUtil.isBoolean(expectedType.get) && booleanPattern.matcher(stepContent.value).matches) {
						return expectedType.get
					}
					val NumberFormat nf = NumberFormat.instance
					try {
						nf.parse(stepContent.value)
						if (typeReferenceUtil.isANumber(expectedType.get)) {
							return expectedType.get
						}
					}catch(ParseException pe) {
						// ignore and try to find type by matching (see fallback below)
					}
				} 
				// (fallback) try to find out without context information
				if (nonFractionalNumberPattern.matcher(stepContent.value).matches) {
					return typeReferenceUtil.longObjectJvmTypeReference
				} else if (booleanPattern.matcher(stepContent.value).matches) {
					return typeReferenceUtil.booleanObjectJvmTypeReference
				} else if (fractionalNumberPattern.matcher(stepContent.value).matches) {
					return typeReferenceUtil.bigDecimalJvmTypeReference
				} else {
					return typeReferenceUtil.stringJvmTypeReference // it is a string (as last resort)
				}
			}
			VariableReference: return determineType(stepContent.variable, expectedType?:Optional.empty)
			default: throw new RuntimeException('''Unknown step content type = '«stepContent.class.name»' for type determination.''')
		}
	}
	
	def dispatch JvmTypeReference determineType(Expression expression, Optional<JvmTypeReference> expectedType) {
		typeReferenceUtil.initWith(expression.eResource)
		switch expression {
			VariableReferencePathAccess: return typeReferenceUtil.jsonElementJvmTypeReference
			JsonObject: return typeReferenceUtil.jsonObjectJvmTypeReference
			JsonArray: return typeReferenceUtil.jsonArrayJvmTypeReference
			JsonNumber: return typeReferenceUtil.numberJvmTypeReference // TODO should be big decimal
			JsonString: return typeReferenceUtil.stringJvmTypeReference
			JsonBoolean: return typeReferenceUtil.booleanObjectJvmTypeReference
			JsonNull: throw new RuntimeException("Not implemented yet")
			VariableReference: return expression.variable.determineType(expectedType?:Optional.empty)
			Comparison: if(expression.comparator === null) {
				expression.left.determineType(expectedType?:Optional.empty)
			} else {
				return typeReferenceUtil.booleanPrimitiveJvmTypeReference
			}
			NullOrBoolCheck: return typeReferenceUtil.booleanPrimitiveJvmTypeReference
			default: { throw new RuntimeException("Expression of type '"+expression.class.canonicalName+"' is unknown")}
		}
	}
	
	def dispatch JvmTypeReference determineType(Variable variable, Optional<JvmTypeReference> expectedType) {
		typeReferenceUtil.initWith(variable.eResource)
		val result = switch variable {
			AssignmentVariable: typeComputer.determineType(variable)
			EnvironmentVariable: {
				if (variable.nonConfidential) {
					typeReferenceUtil.stringJvmTypeReference
				} else {
					typeReferenceUtil.buildFrom(MaskingString)
				}
			}
			TemplateVariable: typeComputer.getVariablesWithTypes(
				EcoreUtil2.getContainerOfType(variable, TemplateContainer)).get(variable).get
			TestParameter: typeReferenceUtil.objectJvmTypeReference
			default: throw new RuntimeException('''Variable of type='«variable.class.canonicalName»' is unknown''')
		}
		if (result === null) {
			throw new RuntimeException('''Type of variable='«variable.name»' could not be determined. Please check you classpath setup.''')
		}
		return result
	}
	
	def boolean coercibleTo(Expression expression, JvmTypeReference wantedType) {
		coercionComputer.initWith(expression.eResource)
		val expressionType = determineType(expression, Optional.of(wantedType))
		return coercionComputer.isTypeCoercionPossible(wantedType, expressionType)
	}
	
	def JvmTypeReference moreSpecificType(JvmTypeReference left, JvmTypeReference right) {
		if(left.qualifiedName.equals(String.name)) {
			return right
		}else{
			return left
		}
	}

	def Map<String, JvmTypeReference> getEnvironmentVariablesTypeMap(Iterable<EnvironmentVariable> envParams) {
		val envParameterVariablesTypeMap = newHashMap
		if (!envParams.empty) {
			typeReferenceUtil.initWith(envParams.head.eResource)
			val stringTypeReference = typeReferenceUtil.stringJvmTypeReference
			val maskingStringTypeReference = typeReferenceUtil.buildFrom(MaskingString)  
			envParams.forEach[
				envParameterVariablesTypeMap.put(name, if (nonConfidential) { stringTypeReference } else { maskingStringTypeReference })
			]
		}
		return envParameterVariablesTypeMap
	}	
	
	/** find the most likely type for each of the comparison components (left and right) */
	def JvmTypeReference coercedTypeOfComparison(Comparison comparison, Optional<JvmTypeReference> wantedType) {
		typeReferenceUtil.initWith(comparison.eResource)
		coercionComputer.initWith(comparison.eResource)
		val leftType = comparison.left.determineType(wantedType?:Optional.empty)
		if (comparison.comparator === null) { // just a simple expression without the right component ?
			return leftType
		}
		val rightType = comparison.right.determineType(wantedType?:Optional.empty)
		switch (comparison.comparator) {
			ComparatorMatches:
				return typeReferenceUtil.stringJvmTypeReference // when matching, both components must be strings
			ComparatorGreaterThan,
			ComparatorLessThan: // must be something orderable
				if (coercionComputer.coercableToCommonOrderable(leftType, rightType)) {
					return coercionComputer.coercedCommonOrderableType(leftType, rightType)
				} else {
					return null; // impossible
				}
			ComparatorEquals: {
				if (coercionComputer.coercableToCommonComparable(leftType, rightType)) {
					return coercionComputer.coercedCommonComparableType(leftType, rightType)
				} else {
					return null; // impossible
				}
			}
			default:
				throw new RuntimeException('''Unknown comparision type «comparison.comparator»''')
		}
	}
	
}