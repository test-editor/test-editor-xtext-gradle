package org.testeditor.dsl.common.util

import java.util.Collection
import org.eclipse.xtext.common.types.JvmTypeReference
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameter
import org.junit.runners.Parameterized.Parameters

import static org.hamcrest.CoreMatchers.is
import static org.junit.Assert.assertThat
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.when

@RunWith(Parameterized)
class JvmTypeReferenceUtilTest {
	
	@Parameters(name='default value for {0} is {1}')
	def static Collection<Object[]> data() {
		return #[
			#[Boolean.TYPE, 'false'],
			#[Byte.TYPE, '0'],
			#[Character.TYPE, '\u0000'],
			#[Double.TYPE, '0'],
			#[Float.TYPE, '0'],
			#[Integer.TYPE, '0'],
			#[Long.TYPE, '0'],
			#[Short.TYPE, '0'],
			
			#[Object, 'null'],
			#[String, 'null']
		]
	}
	
	@Parameter(value=0)
	public Class type

	@Parameter(value=1)
	public String expectedDefaultValue

	@Test
	def void testDefaultValues() {
		// given
		val typeReferenceUtil = new JvmTypeReferenceUtil
		val mockTypeRef = mock(JvmTypeReference)
		when(mockTypeRef.simpleName).thenReturn(type.simpleName)

		// when
		val actual = typeReferenceUtil.defaultValue(mockTypeRef)

		// then
		assertThat(actual, is(expectedDefaultValue))
	}
}