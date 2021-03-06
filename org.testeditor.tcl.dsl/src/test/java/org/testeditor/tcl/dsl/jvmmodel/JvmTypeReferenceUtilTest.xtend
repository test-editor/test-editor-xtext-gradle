package org.testeditor.tcl.dsl.jvmmodel

import javax.inject.Inject
import org.eclipse.xtext.xbase.typesystem.conformance.TypeConformanceComputationArgument
import org.junit.Before
import org.junit.Ignore
import org.junit.Test
import org.testeditor.dsl.common.util.JvmTypeReferenceUtil

/**
 * Jvm type reference util tests are implemented in the tcl package to 
 * make sure that these tests are executed in the context of a xtext dsl
 * with access to a non null resource set, which again is heavyly used
 * by the class itself. 
 */
class JvmTypeReferenceUtilTest extends AbstractTclGeneratorIntegrationTest {

	@Inject JvmTypeReferenceUtil typeReferenceUtil // class under test
	@Inject JvmTypeReferenceUtil utilForTypeGenerationComparison
	
	val standardTestFlags = new TypeConformanceComputationArgument(false, false, false, false, false, true)

	enum TestEnum { a, b, c }
	
	@Before
	def void setupTypeReferenceUtils() {
		typeReferenceUtil.initWith(resourceSet)
		utilForTypeGenerationComparison.initWith(resourceSet)
	}

	@Test
	def void testTestEnumIsEnum() {
		// given+when
		val isAssignable = typeReferenceUtil.isAssignableFrom(typeReferenceUtil.enumJvmTypeReference, typeReferenceUtil.buildFrom(TestEnum), standardTestFlags)

		// then
		isAssignable.assertTrue
	}

	@Test
	def void testBooleanToBooleanObjectAssignmentWithoutBoxing() {
		// given + when				
		val isAssignable = typeReferenceUtil.isAssignableFrom(typeReferenceUtil.booleanObjectJvmTypeReference,
			typeReferenceUtil.buildFrom(Boolean), standardTestFlags)

		// then
		isAssignable.assertTrue
	}

	@Test
	def void testPrimitiveToBooleanObjectAssignmentWithoutBoxing() {
		// given + when		
		val isAssignable = typeReferenceUtil.isAssignableFrom(typeReferenceUtil.booleanObjectJvmTypeReference,
			typeReferenceUtil.booleanPrimitiveJvmTypeReference, standardTestFlags)

		// then
		isAssignable.assertFalse
	}

	@Test
	def void testJsonElementToBooleanObjectAssignmentWithoutBoxing() {
		// given + when		
		val isAssignable = typeReferenceUtil.isAssignableFrom(typeReferenceUtil.booleanObjectJvmTypeReference,
			typeReferenceUtil.jsonElementJvmTypeReference, standardTestFlags)

		// then
		isAssignable.assertFalse
	}

	@Ignore // this test should run within a (sane java) project and its resourceSet but fails locally with an exception 
	@Test
	def void testPrimitiveToBooleanObjectAssignmentWithBoxing() {
		// given + when		
		val isAssignable = typeReferenceUtil.isAssignableFrom(typeReferenceUtil.booleanObjectJvmTypeReference,
			typeReferenceUtil.booleanPrimitiveJvmTypeReference)

		// then
		isAssignable.assertTrue
	}

	@Test
	def void testTypeEquality() {
		// given
		val jsonArray = typeReferenceUtil.jsonArrayJvmTypeReference
		val myJsonArray = utilForTypeGenerationComparison.jsonArrayJvmTypeReference
		assertTrue(jsonArray !== myJsonArray) // be sure to use two different instances!
		
		// when
		val result = typeReferenceUtil.isJsonArray(myJsonArray)
		
		// then
		result.assertTrue
	}
	
	@Test
	def void testTypeRecognition() {
		// given + when + then
		typeReferenceUtil.isBigDecimal(typeReferenceUtil.bigDecimalJvmTypeReference).assertTrue
		typeReferenceUtil.isBigDecimal(typeReferenceUtil.longObjectJvmTypeReference).assertFalse
		
		typeReferenceUtil.isLong(typeReferenceUtil.longObjectJvmTypeReference).assertTrue
		typeReferenceUtil.isLong(typeReferenceUtil.longPrimitiveJvmTypeReference).assertTrue
		typeReferenceUtil.isLong(typeReferenceUtil.bigDecimalJvmTypeReference).assertFalse
		
		typeReferenceUtil.isInt(typeReferenceUtil.intObjectJvmTypeReference).assertTrue
		typeReferenceUtil.isInt(typeReferenceUtil.intPrimitiveJvmTypeReference).assertTrue
		typeReferenceUtil.isInt(typeReferenceUtil.bigDecimalJvmTypeReference).assertFalse
		
		typeReferenceUtil.isBoolean(typeReferenceUtil.booleanObjectJvmTypeReference).assertTrue
		typeReferenceUtil.isBoolean(typeReferenceUtil.booleanPrimitiveJvmTypeReference).assertTrue
		typeReferenceUtil.isBoolean(typeReferenceUtil.stringJvmTypeReference).assertFalse
		
		typeReferenceUtil.isString(typeReferenceUtil.stringJvmTypeReference).assertTrue
		typeReferenceUtil.isString(typeReferenceUtil.booleanObjectJvmTypeReference).assertFalse
		
		typeReferenceUtil.isJsonArray(typeReferenceUtil.jsonArrayJvmTypeReference).assertTrue
		typeReferenceUtil.isJsonArray(typeReferenceUtil.stringJvmTypeReference).assertFalse
		typeReferenceUtil.isJsonElement(typeReferenceUtil.jsonElementJvmTypeReference).assertTrue
		typeReferenceUtil.isJsonElement(typeReferenceUtil.stringJvmTypeReference).assertFalse
		typeReferenceUtil.isJsonObject(typeReferenceUtil.jsonObjectJvmTypeReference).assertTrue
		typeReferenceUtil.isJsonObject(typeReferenceUtil.stringJvmTypeReference).assertFalse
		typeReferenceUtil.isJsonPrimitive(typeReferenceUtil.jsonPrimitiveJvmTypeReference).assertTrue
		typeReferenceUtil.isJsonPrimitive(typeReferenceUtil.stringJvmTypeReference).assertFalse
		
		typeReferenceUtil.isANumber(typeReferenceUtil.intObjectJvmTypeReference).assertTrue
		typeReferenceUtil.isANumber(typeReferenceUtil.longObjectJvmTypeReference).assertTrue
		typeReferenceUtil.isANumber(typeReferenceUtil.bigDecimalJvmTypeReference).assertTrue
		
		typeReferenceUtil.isNumber(typeReferenceUtil.numberJvmTypeReference).assertTrue
		typeReferenceUtil.isNumber(typeReferenceUtil.bigDecimalJvmTypeReference).assertFalse

		typeReferenceUtil.isOrderable(typeReferenceUtil.bigDecimalJvmTypeReference).assertTrue
		typeReferenceUtil.isOrderable(typeReferenceUtil.intPrimitiveJvmTypeReference).assertTrue
		typeReferenceUtil.isOrderable(typeReferenceUtil.longPrimitiveJvmTypeReference).assertTrue
		typeReferenceUtil.isOrderable(typeReferenceUtil.stringJvmTypeReference).assertFalse // strings are currently not orderable (<, <=, >, >=)
	}
	
}
